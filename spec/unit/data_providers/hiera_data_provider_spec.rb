#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'

describe "when using a hiera data provider" do
  include PuppetSpec::Compiler

  # There is a fully configured 'sample' environment in fixtures at this location
  let(:environmentpath) { parent_fixture('environments') }

  let(:facts) { Puppet::Node::Facts.new("facts", {}) }

  around(:each) do |example|
    # Initialize settings to get a full compile as close as possible to a real
    # environment load
    Puppet.settings.initialize_global_settings
    # Initialize loaders based on the environmentpath. It does not work to
    # just set the setting environmentpath for some reason - this achieves the same:
    # - first a loader is created, loading directory environments from the fixture (there is
    # one environment, 'sample', which will be loaded since the node references this
    # environment by name).
    # - secondly, the created env loader is set as 'environments' in the puppet context.
    #
    loader = Puppet::Environments::Directories.new(environmentpath, [])
    Puppet.override(:environments => loader) do
      example.run
    end
  end

  def compile_and_get_notifications(environment, code = nil)
    extract_notifications(compile(environment, code))
  end

  def compile(environment, code = nil)
    Puppet[:code] = code if code
    node = Puppet::Node.new("testnode", :facts => facts, :environment => environment)
    compiler = Puppet::Parser::Compiler.new(node)
    compiler.topscope['domain'] = 'example.com'
    block_given? ? compiler.compile { |catalog| yield(compiler); catalog } : compiler.compile
  end

  def extract_notifications(catalog)
    catalog.resources.map(&:ref).select { |r| r.start_with?('Notify[') }.map { |r| r[7..-2] }
  end

  it 'uses default configuration for environment and module data' do
    resources = compile_and_get_notifications('hiera_defaults')
    expect(resources).to include('module data param_a is 100, param default is 200, env data param_c is 300')
  end

  it 'reads hiera.yaml in environment root and configures multiple json and yaml providers' do
    resources = compile_and_get_notifications('hiera_env_config')
    expect(resources).to include("env data param_a is 10, env data param_b is 20, env data param_c is 30, env data param_d is 40, env data param_e is 50, env data param_yaml_utf8 is \u16EB\u16D2\u16E6, env data param_json_utf8 is \u16A0\u16C7\u16BB")
  end

  it 'reads hiera.yaml in module root and configures multiple json and yaml providers' do
    resources = compile_and_get_notifications('hiera_module_config')
    expect(resources).to include('module data param_a is 100, module data param_b is 200, module data param_c is 300, module data param_d is 400, module data param_e is 500')
  end

  it 'keeps lookup_options in one module separate from lookup_options in another' do
    resources1 = compile('hiera_modules', 'include one').resources.select {|r| r.ref.start_with?('Class[One]')}
    resources2 = compile('hiera_modules', 'include two').resources.select {|r| r.ref.start_with?('Class[One]')}
    expect(resources1).to eq(resources2)
  end

  it 'does not perform merge of values declared in environment and module when resolving parameters' do
    resources = compile_and_get_notifications('hiera_misc')
    expect(resources).to include('env 1, ')
  end

  it 'performs hash merge of values declared in environment and module' do
    resources = compile_and_get_notifications('hiera_misc', '$r = lookup(one::test::param, Hash[String,String], hash) notify{"${r[key1]}, ${r[key2]}":}')
    expect(resources).to include('env 1, module 2')
  end

  it 'performs unique merge of values declared in environment and module' do
    resources = compile_and_get_notifications('hiera_misc', '$r = lookup(one::array, Array[String], unique) notify{"${r}":}')
    expect(resources.size).to eq(1)
    expect(resources[0][1..-2].split(', ')).to contain_exactly('first', 'second', 'third', 'fourth')
  end

  it 'performs merge found in lookup_options in environment of values declared in environment and module' do
    resources = compile_and_get_notifications('hiera_misc', 'include one::lopts_test')
    expect(resources.size).to eq(1)
    expect(resources[0]).to eq('A, B, C, MA, MB, MC')
  end

  it 'performs merge found in lookup_options in module of values declared in environment and module' do
    resources = compile_and_get_notifications('hiera_misc', 'include one::loptsm_test')
    expect(resources.size).to eq(1)
    expect(resources[0]).to eq('A, B, C, MA, MB, MC')
  end

  it "will not find 'lookup_options' as a regular value" do
    expect { compile_and_get_notifications('hiera_misc', '$r = lookup("lookup_options")') }.to raise_error(Puppet::DataBinding::LookupError, /did not find a value/)
  end

  it 'does find unqualified keys in the environment' do
    resources = compile_and_get_notifications('hiera_misc', 'notify{lookup(ukey1):}')
    expect(resources).to include('Some value')
  end

  it 'does not find unqualified keys in the module' do
    expect do
      compile_and_get_notifications('hiera_misc', 'notify{lookup(ukey2):}')
    end.to raise_error(Puppet::ParseError, /did not find a value for the name 'ukey2'/)
  end

  it 'can use interpolation lookup method "alias"' do
    resources = compile_and_get_notifications('hiera_misc', 'notify{lookup(km_alias):}')
    expect(resources).to include('Value from interpolation with alias')
  end

  it 'can use interpolation lookup method "lookup"' do
    resources = compile_and_get_notifications('hiera_misc', 'notify{lookup(km_lookup):}')
    expect(resources).to include('Value from interpolation with lookup')
  end

  it 'can use interpolation lookup method "hiera"' do
    resources = compile_and_get_notifications('hiera_misc', 'notify{lookup(km_hiera):}')
    expect(resources).to include('Value from interpolation with hiera')
  end

  it 'can use interpolation lookup method "literal"' do
    resources = compile_and_get_notifications('hiera_misc', 'notify{lookup(km_literal):}')
    expect(resources).to include('Value from interpolation with literal')
  end

  it 'can use interpolation lookup method "scope"' do
    resources = compile_and_get_notifications('hiera_misc', '$target_scope = "with scope" notify{lookup(km_scope):}')
    expect(resources).to include('Value from interpolation with scope')
  end

  it 'can use interpolation using default lookup method (scope)' do
    resources = compile_and_get_notifications('hiera_misc', '$target_default = "with default" notify{lookup(km_default):}')
    expect(resources).to include('Value from interpolation with default')
  end

  it 'performs lookup using qualified expressions in interpolation' do
    resources = compile_and_get_notifications('hiera_misc', "$os = { name => 'Fedora' } notify{lookup(km_qualified):}")
    expect(resources).to include('Value from qualified interpolation OS = Fedora')
  end

  it 'can have multiple interpolate expressions in one value' do
    resources = compile_and_get_notifications('hiera_misc', 'notify{lookup(km_multi):}')
    expect(resources).to include('cluster/%{::cluster}/%{role}')
  end

  it 'performs single quoted interpolation' do
    resources = compile_and_get_notifications('hiera_misc', 'notify{lookup(km_sqalias):}')
    expect(resources).to include('Value from interpolation with alias')
  end

  it 'uses compiler lifecycle for caching' do
    Puppet[:code] = 'notify{lookup(one::my_var):}'
    node = Puppet::Node.new('testnode', :facts => facts, :environment => 'hiera_module_config')

    compiler = Puppet::Parser::Compiler.new(node)
    compiler.topscope['my_fact'] = 'server1'
    expect(extract_notifications(compiler.compile)).to include('server1')

    compiler = Puppet::Parser::Compiler.new(node)
    compiler.topscope['my_fact'] = 'server2'
    expect(extract_notifications(compiler.compile)).to include('server2')

    compiler = Puppet::Parser::Compiler.new(node)
    expect(extract_notifications(compiler.compile)).to include('In name.yaml')
  end

  it 'traps endless interpolate recursion' do
    expect do
      compile_and_get_notifications('hiera_misc', '$r1 = "%{r2}" $r2 = "%{r1}" notify{lookup(recursive):}')
    end.to raise_error(Puppet::DataBinding::RecursiveLookupError, /detected in \[recursive, scope:r1, scope:r2\]/)
  end

  it 'does not consider use of same key in the lookup and scope namespaces as recursion' do
    resources = compile_and_get_notifications('hiera_misc', 'notify{lookup(domain):}')
    expect(resources).to include('-- example.com --')
  end

  it 'traps bad alias declarations' do
    expect do
      compile_and_get_notifications('hiera_misc', "$r1 = 'Alias within string %{alias(\"r2\")}' $r2 = '%{r1}' notify{lookup(recursive):}")
    end.to raise_error(Puppet::DataBinding::LookupError, /'alias' interpolation is only permitted if the expression is equal to the entire string/)
  end

  it 'reports syntax errors for JSON files' do
    expect do
      compile_and_get_notifications('hiera_bad_syntax_json')
    end.to raise_error(Puppet::DataBinding::LookupError, /Unable to parse \(#{environmentpath}[^)]+\):/)
  end

  it 'reports syntax errors for YAML files' do
    expect do
      compile_and_get_notifications('hiera_bad_syntax_yaml')
    end.to raise_error(Puppet::DataBinding::LookupError, /Unable to parse \(#{environmentpath}[^)]+\):/)
  end

  describe 'when using explain' do
    it 'will report config path (original and resolved), data path (original and resolved), and interpolation (before and after)' do
      compile('hiera_misc', '$target_scope = "with scope"') do |compiler|
        lookup_invocation = Puppet::Pops::Lookup::Invocation.new(compiler.topscope, {}, {}, true)
        Puppet::Pops::Lookup.lookup('km_scope', nil, nil, nil, nil, lookup_invocation)
        expect(lookup_invocation.explainer.explain).to include(<<-EOS)
      Path "#{environmentpath}/hiera_misc/data/common.yaml"
        Original path: "common.yaml"
        Interpolation on "Value from interpolation %{scope("target_scope")}"
          Global Scope
            Found key: "target_scope" value: "with scope"
        Found key: "km_scope" value: "Value from interpolation with scope"
          EOS
      end
    end

    it 'will report that merge options was found in the lookup_options hash' do
      compile('hiera_misc', '$target_scope = "with scope"') do |compiler|
        lookup_invocation = Puppet::Pops::Lookup::Invocation.new(compiler.topscope, {}, {}, true)
        Puppet::Pops::Lookup.lookup('one::loptsm_test::hash', nil, nil, nil, nil, lookup_invocation)
        expect(lookup_invocation.explainer.explain).to include("Using merge options from \"lookup_options\" hash")
      end
    end

    it 'will report lookup_options details in combination with details of found value' do
      compile('hiera_misc', '$target_scope = "with scope"') do |compiler|
        lookup_invocation = Puppet::Pops::Lookup::Invocation.new(compiler.topscope, {}, {}, Puppet::Pops::Lookup::Explainer.new(true))
        Puppet::Pops::Lookup.lookup('one::loptsm_test::hash', nil, nil, nil, nil, lookup_invocation)
        expect(lookup_invocation.explainer.explain).to eq(<<EOS)
Searching for "lookup_options"
  Global Data Provider (hiera configuration version 5)
    No such key: "lookup_options"
  Environment Data Provider (hiera configuration version 5)
    Hierarchy entry "Common"
      Path "#{environmentpath}/hiera_misc/data/common.yaml"
        Original path: "common.yaml"
        Found key: "lookup_options" value: {
          "one::lopts_test::hash" => {
            "merge" => "deep"
          }
        }
  Module "one" Data Provider (hiera configuration version 5)
    Hierarchy entry "Common"
      Path "#{environmentpath}/hiera_misc/modules/one/data/common.yaml"
        Original path: "common.yaml"
        Found key: "lookup_options" value: {
          "one::loptsm_test::hash" => {
            "merge" => "deep"
          }
        }
  Merge strategy hash
    Global and Environment
      Found key: "lookup_options" value: {
        "one::lopts_test::hash" => {
          "merge" => "deep"
        }
      }
    Module one
      Found key: "lookup_options" value: {
        "one::loptsm_test::hash" => {
          "merge" => "deep"
        }
      }
    Merged result: {
      "one::loptsm_test::hash" => {
        "merge" => "deep"
      },
      "one::lopts_test::hash" => {
        "merge" => "deep"
      }
    }
Using merge options from "lookup_options" hash
Searching for "one::loptsm_test::hash"
  Merge strategy deep
    Global Data Provider (hiera configuration version 5)
      No such key: "one::loptsm_test::hash"
    Environment Data Provider (hiera configuration version 5)
      Hierarchy entry "Common"
        Path "#{environmentpath}/hiera_misc/data/common.yaml"
          Original path: "common.yaml"
          Found key: "one::loptsm_test::hash" value: {
            "a" => "A",
            "b" => "B",
            "m" => {
              "ma" => "MA",
              "mb" => "MB"
            }
          }
    Module "one" Data Provider (hiera configuration version 5)
      Hierarchy entry "Common"
        Path "#{environmentpath}/hiera_misc/modules/one/data/common.yaml"
          Original path: "common.yaml"
          Found key: "one::loptsm_test::hash" value: {
            "a" => "A",
            "c" => "C",
            "m" => {
              "ma" => "MA",
              "mc" => "MC"
            }
          }
    Merged result: {
      "a" => "A",
      "c" => "C",
      "m" => {
        "ma" => "MA",
        "mc" => "MC",
        "mb" => "MB"
      },
      "b" => "B"
    }
EOS
      end
    end

    it 'will report config path (original and resolved), data path (original and resolved), and interpolation (before and after)' do
      compile('hiera_misc', '$target_scope = "with scope"') do |compiler|
        lookup_invocation = Puppet::Pops::Lookup::Invocation.new(compiler.topscope, {}, {}, Puppet::Pops::Lookup::Explainer.new(true, true))
        Puppet::Pops::Lookup.lookup('one::loptsm_test::hash', nil, nil, nil, nil, lookup_invocation)
        expect(lookup_invocation.explainer.explain).to eq(<<EOS)
Merge strategy hash
  Global Data Provider (hiera configuration version 5)
    No such key: "lookup_options"
  Environment Data Provider (hiera configuration version 5)
    Hierarchy entry "Common"
      Path "#{environmentpath}/hiera_misc/data/common.yaml"
        Original path: "common.yaml"
        Found key: "lookup_options" value: {
          "one::lopts_test::hash" => {
            "merge" => "deep"
          }
        }
  Module "one" Data Provider (hiera configuration version 5)
    Hierarchy entry "Common"
      Path "#{environmentpath}/hiera_misc/modules/one/data/common.yaml"
        Original path: "common.yaml"
        Found key: "lookup_options" value: {
          "one::loptsm_test::hash" => {
            "merge" => "deep"
          }
        }
  Merged result: {
    "one::loptsm_test::hash" => {
      "merge" => "deep"
    },
    "one::lopts_test::hash" => {
      "merge" => "deep"
    }
  }
EOS
      end
    end
  end

  def parent_fixture(dir_name)
    File.absolute_path(File.join(my_fixture_dir(), "../#{dir_name}"))
  end

  def resources_in(catalog)
    catalog.resources.map(&:ref)
  end

end
