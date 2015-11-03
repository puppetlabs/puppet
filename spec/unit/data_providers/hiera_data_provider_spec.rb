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
    compile(environment, code).resources.map(&:ref).select { |r| r.start_with?('Notify[') }.map { |r| r[7..-2] }
  end

  def compile(environment, code = nil)
    Puppet[:code] = code if code
    node = Puppet::Node.new("testnode", :facts => facts, :environment => environment)
    compiler = Puppet::Parser::Compiler.new(node)
    block_given? ? compiler.compile() { |catalog| yield(compiler); catalog } : compiler.compile()
  end

  it 'uses default configuration for environment and module data' do
    resources = compile_and_get_notifications('hiera_defaults')
    expect(resources).to include('module data param_a is 100, param default is 200, env data param_c is 300')
  end

  it 'reads hiera.yaml in environment root and configures multiple json and yaml providers' do
    resources = compile_and_get_notifications('hiera_env_config')
    expect(resources).to include('env data param_a is 10, env data param_b is 20, env data param_c is 30, env data param_d is 40, env data param_e is 50')
  end

  it 'reads hiera.yaml in module root and configures multiple json and yaml providers' do
    resources = compile_and_get_notifications('hiera_module_config')
    expect(resources).to include('module data param_a is 100, module data param_b is 200, module data param_c is 300, module data param_d is 400, module data param_e is 500')
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

  it "can lookup the 'lookup_options' hash as a regular value" do
    resources = compile_and_get_notifications('hiera_misc', '$r = lookup(lookup_options, Hash[String,Hash[String,String]], hash) notify{"${r[one::lopts_test::hash][merge]}":}')
    expect(resources.size).to eq(1)
    expect(resources[0]).to eq('deep')
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

  it 'traps endless interpolate recursion' do
    expect do
      compile_and_get_notifications('hiera_misc', '$r1 = "%{r2}" $r2 = "%{r1}" notify{lookup(recursive):}')
    end.to raise_error(Puppet::DataBinding::RecursiveLookupError, /detected in \[recursive, r1, r2\]/)
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
        value = Puppet::Pops::Lookup.lookup('km_scope', nil, nil, nil, nil, lookup_invocation)
        expect(lookup_invocation.explainer.to_s).to eq(<<EOS)
Data Provider "Hiera Data Provider, version 4"
  ConfigurationPath "#{environmentpath}/hiera_misc/hiera.yaml"
  Data Provider "common"
    Path "#{environmentpath}/hiera_misc/data/common.yaml"
      Original path: common
      Interpolation on "Value from interpolation %{scope("target_scope")}"
        Global Scope"
          Found key: "target_scope" value: "with scope"
      Found key: "km_scope" value: "Value from interpolation with scope"
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
