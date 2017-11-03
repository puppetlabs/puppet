#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'

describe 'Puppet Pal' do
#  before { skip("Puppet::Pal is not available on Ruby 1.9.3") if RUBY_VERSION == '1.9.3' }

  # Require here since it will not work on RUBY < 2.0.0
  require 'puppet_pal'

  include PuppetSpec::Files

  let(:testing_env) do
    {
      'pal_env' => {
        'functions' => functions,
        'lib' => { 'puppet' => lib_puppet },
        'manifests' => manifests,
        'modules' => modules,
        'plans' => plans,
        'tasks' => tasks,
        'types' => types,
      },
      'other_env1' => { 'modules' => {} },
      'other_env2' => { 'modules' => {} },
    }
  end

  let(:functions) { {} }
  let(:manifests) { {} }
  let(:modules) { {} }
  let(:plans) { {} }
  let(:lib_puppet) { {} }
  let(:tasks) { {} }
  let(:types) { {} }

  let(:environments_dir) { Puppet[:environmentpath] }

  let(:testing_env_dir) do
    dir_contained_in(environments_dir, testing_env)
    env_dir = File.join(environments_dir, 'pal_env')
    PuppetSpec::Files.record_tmp(env_dir)
    PuppetSpec::Files.record_tmp(File.join(environments_dir, 'other_env1'))
    PuppetSpec::Files.record_tmp(File.join(environments_dir, 'other_env2'))
    env_dir
  end

  let(:modules_dir) { File.join(testing_env_dir, 'modules') }

  # Without any facts - this speeds up the tests that do not require $facts to have any values
  let(:node_facts) { Hash.new }

  # TODO: to be used in examples for running in an existing env
  #  let(:env) { Puppet::Node::Environment.create(:testing, [modules_dir]) }

  context 'in general - without code in modules or env' do
    let(:modulepath) { [] }

    it 'evaluates code string in a given tmp environment' do
      result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
        ctx.evaluate_script_string('1+2+3')
      end
      expect(result).to eq(6)
    end

    it 'can evaluates more than once in a given tmp environment - each in fresh compiler' do
      result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
        result = ctx.evaluate_script_string('$a = 1+2+3')
        expect { ctx.evaluate_script_string('$a') }.to raise_error(/Unknown variable: 'a'/)
        result
      end
      expect(result).to eq(6)
    end

    it 'evaluates a manifest file in a given tmp environment' do
      result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
        manifest = file_containing('testing.pp', "1+2+3+4")
        ctx.evaluate_script_manifest(manifest)
      end
      expect(result).to eq(10)
    end

    it 'can set variables in any scope' do
      vars = {'a'=> 10, 'x::y' => 20}
      result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts, variables: vars) do |ctx|
        manifest = file_containing('testing.pp', "1+2+3+4+$a+$x::y")
        ctx.evaluate_script_manifest(manifest)
      end
      expect(result).to eq(40)
    end

    it 'errors if variable name is not compliant with variable name rule' do
      vars = {'_a::b'=> 10}
      expect do
        Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts, variables: vars) do |ctx|
          manifest = file_containing('testing.pp', "ok")
          ctx.evaluate_script_manifest(manifest)
        end
      end.to raise_error(/has illegal name/)
    end

    it 'errors if variable value is not RichData compliant' do
      vars = {'a'=> ArgumentError.new("not rich data")}
      expect do
        Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts, variables: vars) do |ctx|
          manifest = file_containing('testing.pp', "$a")
          ctx.evaluate_script_manifest(manifest)
        end
      end.to raise_error(/has illegal type - got: ArgumentError/)
    end

    # deprecated version
    it 'can call a plan using call_plan and specify content in a manifest' do
      result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
        manifest = file_containing('aplan.pp', "plan myplan() { 'brilliant' }")
        ctx.run_plan('myplan', manifest_file: manifest)
      end
      expect(result).to eq('brilliant')
    end

    it 'can call a function' do
      result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
        manifest = file_containing('afunc.pp', "function myfunc($a) { $a * 2 } ")
        ctx.with_script_compiler(manifest_file: manifest) do |compiler|
          compiler.call_function('myfunc',[6])
        end
      end
      expect(result).to eq(12)
    end

    it 'can call a function with a ruby block' do
      result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
        manifest = file_containing('empty.pp', "")
        ctx.with_script_compiler(manifest_file: manifest) do |compiler|
          compiler.call_function('with',[6]) {|x| x * 2}
        end
      end
      expect(result).to eq(12)
    end

    it 'can get the signatures from a puppet function' do
      result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
        manifest = file_containing('afunc.pp', "function myfunc(Integer $a) { $a * 2 } ")
        ctx.with_script_compiler(manifest_file: manifest) do |compiler|
          signatures = compiler.function_signatures('myfunc')
          expect(signatures.is_a?(Array)).to eq(true)
          [signatures[0].callable_with?([10]), signatures[0].callable_with?(['nope'])]
        end
      end
      expect(result).to eq([true, false])
    end

    it 'can get the signatures from a ruby function with multiple dispatch' do
      result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
        manifest = file_containing('afunc.pp', "")
        ctx.with_script_compiler(manifest_file: manifest) do |compiler|
          compiler.function_signatures('lookup')
        end
      end
      expect(result.is_a?(Array)).to eq(true)
      expect(result.all? {|s| s.is_a?(Puppet::Pops::Types::PCallableType) }).to eq(true)
    end

    it 'returns an empty array for function_signatures if function is not found' do
      result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
        manifest = file_containing('afunc.pp', "")
        ctx.with_script_compiler(manifest_file: manifest) do |compiler|
          compiler.function_signatures('no_where_to_be_found')
        end
      end
      expect(result.is_a?(Array)).to eq(true)
      expect(result.empty?).to eq(true)
    end

    it 'parses and returns a Type from a string specification' do
      result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
        manifest = file_containing('main.pp', "type MyType = Float")
        ctx.with_script_compiler(manifest_file: manifest) do |compiler|
          compiler.type('Variant[Integer, Boolean, MyType]')
        end
      end
      expect(result.is_a?(Puppet::Pops::Types::PVariantType)).to eq(true)
      expect(result.types.size).to eq(3)
      expect(result.instance?(3.14)).to eq(true)
    end

  end

  context 'with code in modules and env' do
    let(:modulepath) { [modules_dir] }

    let(:metadata_json_a) {
      {
        'name' => 'example/a',
        'version' => '0.1.0',
        'source' => 'git@github.com/example/example-a.git',
        'dependencies' => [{'name' => 'c', 'version_range' => '>=0.1.0'}],
        'author' => 'Bob the Builder',
        'license' => 'Apache-2.0'
      }
    }

    let(:metadata_json_b) {
      {
        'name' => 'example/b',
        'version' => '0.1.0',
        'source' => 'git@github.com/example/example-b.git',
        'dependencies' => [{'name' => 'c', 'version_range' => '>=0.1.0'}],
        'author' => 'Bob the Builder',
        'license' => 'Apache-2.0'
      }
    }

    let(:metadata_json_c) {
      {
        'name' => 'example/c',
        'version' => '0.1.0',
        'source' => 'git@github.com/example/example-c.git',
        'dependencies' => [],
        'author' => 'Bob the Builder',
        'license' => 'Apache-2.0'
      }
    }

    # TODO: there is something amiss with the metadata wrt dependencies - when metadata is present there is an error
    #       that dependencies could not be resolved. Metadata is therefore commented out.
    #       Dependency based visibility is probably something that we should remove... 
    let(:modules) {
      {
        'a' => {
        'functions' => a_functions,
        'lib' => { 'puppet' => a_lib_puppet },
        'plans' => a_plans,
        'tasks' => a_tasks,
        'types' => a_types,
#        'metadata.json' => metadata_json_a.to_json
        },
        'b' => {
        'functions' => b_functions,
        'lib' => b_lib,
        'plans' => b_plans,
        'tasks' => b_tasks,
        'types' => b_types,
#        'metadata.json' => metadata_json_b.to_json
        },
        'c' => {
        'types' => c_types,
#        'metadata.json' => metadata_json_c.to_json
        },
      }
    }

    let(:a_plans) {
      {
        'aplan.pp' => <<-PUPPET.unindent,
        plan a::aplan() { 'a::aplan value' }
        PUPPET
      }
    }

    let(:a_types) {
      {
        'atype.pp' => <<-PUPPET.unindent,
        type A::Atype = Integer
        PUPPET
      }
    }

    let(:a_tasks) {
      {
        'atask' => '',
      }
    }

    let(:a_functions) {
      {
        'afunc.pp' => 'function a::afunc() { "a::afunc value" }',
      }
    }

    let(:a_lib_puppet) {
      {
        'functions' => {
          'a' => {
            'arubyfunc.rb' => <<-RUBY.unindent,
              require 'stuff/something'
              Puppet::Functions.create_function(:'a::arubyfunc') do
                def arubyfunc
                  Stuff::SOMETHING
                end
              end
              RUBY
          }
        }
      }
    }

    let(:b_plans) {
      {
        'aplan.pp' => <<-PUPPET.unindent,
        plan b::aplan() {}
        PUPPET
      }
    }

    let(:b_types) {
      {
        'atype.pp' => <<-PUPPET.unindent,
        type B::Atype = Integer
        PUPPET
      }
    }

    let(:b_tasks) {
      {
        'atask' => '',
      }
    }

    let(:b_functions) {
      {
        'afunc.pp' => 'function b::afunc() {}',
      }
    }

    let(:b_lib) {
      {
        'puppet' => b_lib_puppet,
        'stuff' => {
          'something.rb' => "module Stuff; SOMETHING = 'something'; end"
        }
      }
    }

    let(:b_lib_puppet) {
      {
        'functions' => {
        'b' => {
        'arubyfunc.rb' => "Puppet::Functions.create_function(:'b::arubyfunc') { def arubyfunc; 'arubyfunc_value'; end }",
        }
        }
      }
    }

    let(:c_types) {
      {
        'atype.pp' => <<-PUPPET.unindent,
        type C::Atype = Integer
        PUPPET
      }
    }
    context 'configured a temporary environment such that' do
      it 'modules are available' do
        result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
          ctx.evaluate_script_string('a::afunc()')
        end
        expect(result).to eq("a::afunc value")
      end

      it 'libs in a given "modulepath" are added to the Ruby $LOAD_PATH' do
        result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
          ctx.evaluate_script_string('a::arubyfunc()')
        end
        expect(result).to eql('something')
      end

      it 'a plan in a module can be called with run_plan' do
        result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do |ctx|
          ctx.evaluate_script_string('run_plan("a::aplan")')
        end
        expect(result).to eq("a::aplan value")
      end

      it 'errors if a block is not given to in_tmp_environment' do
        expect do
          Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts)
          ctx.evaluate_script_string('a::afunc()')
        end.to raise_error(/A block must be given to 'in_tmp_environment/)
      end

      it 'errors if an env_name is given and is not a String[1]' do |ctx|
        expect do
          Puppet::Pal.in_tmp_environment('', modulepath: modulepath, facts: node_facts)
            ctx.evaluate_script_string('a::afunc()')
        end.to raise_error(/temporary environment name has wrong type/)

        expect do
          Puppet::Pal.in_tmp_environment(32, modulepath: modulepath, facts: node_facts)
            ctx.evaluate_script_string('a::afunc()')
        end.to raise_error(/temporary environment name has wrong type/)
      end

      it 'errors if modulepath is something other than an array of strings, empty, or nil' do
        expect do
          Puppet::Pal.in_tmp_environment('pal_env', modulepath: {'a' => 'hm'}, facts: node_facts)
          ctx.evaluate_script_string('a::afunc()')
        end.to raise_error(/modulepath has wrong type/)

        expect do
          Puppet::Pal.in_tmp_environment('pal_env', modulepath: 32, facts: node_facts)
          ctx.evaluate_script_string('a::afunc()')
        end.to raise_error(/modulepath has wrong type/)

        expect do
          Puppet::Pal.in_tmp_environment('pal_env', modulepath: 'dir1;dir2', facts: node_facts)
          ctx.evaluate_script_string('a::afunc()')
        end.to raise_error(/modulepath has wrong type/)

        expect do
          Puppet::Pal.in_tmp_environment('pal_env', modulepath: [''], facts: node_facts)
          ctx.evaluate_script_string('a::afunc()')
        end.to raise_error(/modulepath has wrong type/)
      end
    end

    context 'configured as existing given environment directory such that' do
      it 'modules in it are available from its "modules" directory' do
        result = Puppet::Pal.in_environment('pal_env', env_dir: testing_env_dir, facts: node_facts) do |ctx|
          ctx.evaluate_script_string('a::afunc()')
        end
        expect(result).to eq("a::afunc value")
      end

      it 'libs in a given "modulepath" are added to the Ruby $LOAD_PATH' do
        result = Puppet::Pal.in_environment('pal_env', env_dir: testing_env_dir, facts: node_facts) do |ctx|
          ctx.evaluate_script_string('a::arubyfunc()')
        end
        expect(result).to eql('something')
      end

      it 'a given "modulepath" overrides the default' do
        expect do
          result = Puppet::Pal.in_environment('pal_env', env_dir: testing_env_dir, modulepath: [], facts: node_facts) do |ctx|
            ctx.evaluate_script_string('a::afunc()')
          end
        end.to raise_error(/Unknown function: 'a::afunc'/)
      end

      it 'a "pre_modulepath" is prepended and a "post_modulepath" is appended to the effective modulepath' do
        other_modules1 = File.join(environments_dir, 'other_env1/modules')
        other_modules2 = File.join(environments_dir, 'other_env2/modules')
        result = Puppet::Pal.in_environment('pal_env', env_dir: testing_env_dir, 
          pre_modulepath: [other_modules1],
          post_modulepath: [other_modules2],
          facts: node_facts
        ) do |ctx|
          the_modulepath = Puppet.lookup(:environments).get('pal_env').modulepath
          the_modulepath[0] == other_modules1 && the_modulepath[-1] == other_modules2
        end
        expect(result).to be(true)
      end

      it 'a plan in a module can be called with run_plan' do
        result = Puppet::Pal.in_environment('pal_env', env_dir: testing_env_dir, facts: node_facts) do |ctx|
          ctx.evaluate_script_string('run_plan("a::aplan")')
        end
        expect(result).to eq("a::aplan value")
      end

      it 'can set variables in any scope' do
        vars = {'a'=> 10, 'x::y' => 20}
        result = Puppet::Pal.in_environment('pal_env', env_dir: testing_env_dir, facts: node_facts, variables: vars) do |ctx|
          manifest = file_containing('testing.pp', "1+2+3+4+$a+$x::y")
          ctx.evaluate_script_manifest(manifest)
        end
        expect(result).to eq(40)
      end

      it 'errors in a meaningful way when a non existing env name is given' do
        testing_env_dir # creates the structure
        expect do
          Puppet::Pal.in_environment('blah_env', env_dir: testing_env_dir.chop, facts: node_facts) do |ctx|
            ctx.evaluate_script_string('run_plan("a::aplan")')
          end
        end.to raise_error(/The environment directory '.*' does not exist/)
      end

      it 'errors if an env_name is given and is not a String[1]' do |ctx|
        expect do
          Puppet::Pal.in_environment('', env_dir: testing_env_dir, facts: node_facts)
            ctx.evaluate_script_string('a::afunc()')
        end.to raise_error(/env_name has wrong type/)

        expect do
          Puppet::Pal.in_environment(32, env_dir: testing_env_dir, facts: node_facts)
            ctx.evaluate_script_string('a::afunc()')
        end.to raise_error(/env_name has wrong type/)
      end

      it 'errors if modulepath is something other than an array of strings, empty, or nil' do
        expect do
          Puppet::Pal.in_environment('pal_env', env_dir: testing_env_dir, modulepath: {'a' => 'hm'}, facts: node_facts)
          ctx.evaluate_script_string('a::afunc()')
        end.to raise_error(/modulepath has wrong type/)

        expect do
          Puppet::Pal.in_environment('pal_env', env_dir: testing_env_dir, modulepath: 32, facts: node_facts)
          ctx.evaluate_script_string('a::afunc()')
        end.to raise_error(/modulepath has wrong type/)

        expect do
          Puppet::Pal.in_environment('pal_env', env_dir: testing_env_dir, modulepath: 'dir1;dir2', facts: node_facts)
          ctx.evaluate_script_string('a::afunc()')
        end.to raise_error(/modulepath has wrong type/)

        expect do
          Puppet::Pal.in_environment('pal_env', env_dir: testing_env_dir, modulepath: [''], facts: node_facts)
          ctx.evaluate_script_string('a::afunc()')
        end.to raise_error(/modulepath has wrong type/)
      end

      it 'errors if env_dir and envpath are both given' do
        testing_env_dir # creates the structure
        expect do
          Puppet::Pal.in_environment('blah_env', env_dir: testing_env_dir, envpath: environments_dir, facts: node_facts) do |ctx|
            ctx.evaluate_script_string('irrelevant')
          end
        end.to raise_error(/Cannot use 'env_dir' and 'envpath' at the same time/)
      end
    end

    context 'configured as existing given envpath such that' do
      it 'modules in it are available from its "modules" directory' do
        testing_env_dir # creates the structure
        result = Puppet::Pal.in_environment('pal_env', envpath: environments_dir, facts: node_facts) do |ctx|
          ctx.evaluate_script_string('a::afunc()')
        end
        expect(result).to eq("a::afunc value")
      end

      it 'a given "modulepath" overrides the default' do
        testing_env_dir # creates the structure
        expect do
          result = Puppet::Pal.in_environment('pal_env', envpath: environments_dir, modulepath: [], facts: node_facts) do |ctx|
            ctx.evaluate_script_string('a::afunc()')
          end
        end.to raise_error(/Unknown function: 'a::afunc'/)
      end

      it 'a "pre_modulepath" is prepended and a "post_modulepath" is appended to the effective modulepath' do
        testing_env_dir # creates the structure
        other_modules1 = File.join(environments_dir, 'other_env1/modules')
        other_modules2 = File.join(environments_dir, 'other_env2/modules')
        result = Puppet::Pal.in_environment('pal_env', envpath: environments_dir, 
          pre_modulepath: [other_modules1],
          post_modulepath: [other_modules2],
          facts: node_facts
        ) do |ctx|
          the_modulepath = Puppet.lookup(:environments).get('pal_env').modulepath
          the_modulepath[0] == other_modules1 && the_modulepath[-1] == other_modules2
        end
        expect(result).to be(true)
      end

      it 'a plan in a module can be called with run_plan' do
        testing_env_dir # creates the structure
        result = Puppet::Pal.in_environment('pal_env', envpath: environments_dir, facts: node_facts) do |ctx|
          ctx.evaluate_script_string('run_plan("a::aplan")')
        end
        expect(result).to eq("a::aplan value")
      end

      it 'the envpath can have multiple entries - that are searched for the given env' do
        testing_env_dir # creates the structure
        several_dirs = "/tmp/nowhere/to/be/found:#{environments_dir}"
        result = Puppet::Pal.in_environment('pal_env', envpath: environments_dir, facts: node_facts) do |ctx|
          ctx.evaluate_script_string('run_plan("a::aplan")')
        end
        expect(result).to eq("a::aplan value")
      end

      it 'errors in a meaningful way when a non existing env name is given' do
        testing_env_dir # creates the structure
        expect do
          Puppet::Pal.in_environment('blah_env', envpath: environments_dir, facts: node_facts) do |ctx|
            ctx.evaluate_script_string('run_plan("a::aplan")')
          end
        end.to raise_error(/No directory found for the environment 'blah_env' on the path '.*'/)
      end

      it 'errors if a block is not given to in_environment' do
        expect do
          Puppet::Pal.in_environment('blah_env', envpath: environments_dir, facts: node_facts)
        end.to raise_error(/A block must be given to 'in_environment/)
      end

      it 'errors if envpath is something other than a string' do
        testing_env_dir # creates the structure
        expect do
          Puppet::Pal.in_environment('blah_env', envpath: '', facts: node_facts) do |ctx|
            ctx.evaluate_script_string('irrelevant')
          end
        end.to raise_error(/envpath has wrong type/)

        expect do
          Puppet::Pal.in_environment('blah_env', envpath: [environments_dir], facts: node_facts) do |ctx|
            ctx.evaluate_script_string('irrelevant')
          end
        end.to raise_error(/envpath has wrong type/)
      end

    end

    it 'sets the facts if they are not given' do
      testing_env_dir # creates the structure
      result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath ) do |ctx|
        ctx.evaluate_script_string("$facts =~ Hash and $facts[puppetversion] == '#{Puppet.version}'")
      end
      expect(result).to eq(true)
    end

  end
end
