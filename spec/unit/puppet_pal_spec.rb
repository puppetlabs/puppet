#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/files'

describe 'Puppet Pal' do
  before { skip("Puppet::Pal is not available on Ruby 1.9.3") if RUBY_VERSION == '1.9.3' }

  # Require here since it will not work on RUBY < 2.0.0
  require 'puppet_pal'

  include PuppetSpec::Files

  let(:testing_env) do
    {
      'testing' => {
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
    env_dir = File.join(environments_dir, 'testing')
    PuppetSpec::Files.record_tmp(env_dir)
    env_dir
  end

  let(:modules_dir) { File.join(testing_env_dir, 'modules') }
#  let(:env) { Puppet::Node::Environment.create(:testing, [modules_dir]) }
#  let(:node) { Puppet::Node.new('test', :environment => env) }
#  let(:loader) { Loaders.find_loader(nil) }
#  let(:tasks_feature) { false }

  context 'with empty modulepath' do
    let(:modulepath) { [] }

    it 'evaluates code string in a given tmp environment' do
      result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath) do |ctx|
        ctx.evaluate_script_string('1+2+3')
      end
      expect(result).to eq(6)
    end

    it 'evaluates a manifest file in a given tmp environment' do
      result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath) do |ctx|
        manifest = file_containing('testing.pp', "1+2+3+4")
        ctx.evaluate_script_manifest(manifest)
      end
      expect(result).to eq(10)
    end

    it 'can call a plan using call_plan and specify content in a manifest' do
      result = Puppet::Pal.in_tmp_environment('pal_env', modulepath: modulepath) do | ctx|
        manifest = file_containing('aplan.pp', "plan myplan() { 'brilliant' }")
        ctx.run_plan('myplan', manifest_file: manifest)
      end
      expect(result).to eq('brilliant')
    end

  end

end

