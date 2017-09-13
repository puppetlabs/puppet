#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_pal'
require 'puppet_spec/files'

describe 'Puppet Pal' do
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
      result = Puppet::Pal.in_tmp_environment('pal_env', modulepath) do
        Puppet::Pal.evaluate_script_string('1+2+3')
      end
      expect(result).to eq(6)
    end

    it 'evaluates a manifest file in a given tmp environment' do
      result = Puppet::Pal.in_tmp_environment('pal_env', modulepath) do
        manifest = file_containing('testing.pp', "1+2+3+4")
        Puppet::Pal.evaluate_script_manifest(manifest)
      end
      expect(result).to eq(10)
    end

  end

end

