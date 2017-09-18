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
      }
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
    env_dir
  end

  let(:modules_dir) { File.join(testing_env_dir, 'modules') }

  # Without any facts - this speeds up the tests that do not require $facts to have any values
  let(:node_facts) { Hash.new }

  # TODO: to be used in examples for running in an existing env
  #  let(:env) { Puppet::Node::Environment.create(:testing, [modules_dir]) }

  context 'without code in modules or env' do
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

    it 'can call a plan using call_plan and specify content in a manifest' do
      result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath, facts: node_facts) do | ctx|
        manifest = file_containing('aplan.pp', "plan myplan() { 'brilliant' }")
        ctx.run_plan('myplan', manifest_file: manifest)
      end
      expect(result).to eq('brilliant')
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
        'lib' => { 'puppet' => b_lib_puppet },
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
        'arubyfunc.rb' => "Puppet::Functions.create_function(:'a::arubyfunc') { def arubyfunc; end }",
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

      it 'a given "modulepath" overrides the default' do
        expect do
          result = Puppet::Pal.in_environment('pal_env', env_dir: testing_env_dir, modulepath: [], facts: node_facts) do |ctx|
            ctx.evaluate_script_string('a::afunc()')
          end
        end.to raise_error(/Unknown function: 'a::afunc'/)
      end

      it 'a plan in a module can be called with run_plan' do
        result = Puppet::Pal.in_environment('pal_env', env_dir: testing_env_dir, facts: node_facts) do |ctx|
          ctx.evaluate_script_string('run_plan("a::aplan")')
        end
        expect(result).to eq("a::aplan value")
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

      it 'a plan in a module can be called with run_plan' do
        testing_env_dir # creates the structure
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
