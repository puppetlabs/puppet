require 'puppet'
require 'spec_helper'
require 'puppet_spec/compiler'
require 'matchers/resource'
require 'puppet/parser/script_compiler'

describe 'the script compiler' do
  include PuppetSpec::Compiler
  include PuppetSpec::Files
  include Matchers::Resource
  before(:each) do
    Puppet[:tasks] = true
  end

  context "when used" do
    let(:env_name) { 'testenv' }
    let(:environments_dir) { Puppet[:environmentpath] }
    let(:env_dir) { File.join(environments_dir, env_name) }
    let(:manifest) { Puppet::Node::Environment::NO_MANIFEST }
    let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(populated_env_dir, 'modules')], manifest) }
    let(:node) { Puppet::Node.new("test", :environment => env) }

    let(:env_dir_files) {
      {
        'manifests' => {
          'good.pp' => "'good'\n"
        },
        'modules' => {
          'test' => {
            'plans' => {
               'run_me.pp' => 'plan test::run_me() { "worked2" }'
            }
          }
        }
      }
    }

    let(:populated_env_dir) do
      dir_contained_in(environments_dir, env_name => env_dir_files)
      PuppetSpec::Files.record_tmp(env_dir)
      env_dir
    end

    let(:script_compiler) do
      Puppet::Parser::ScriptCompiler.new(env, node.name)
    end

    context 'is configured such that' do
      it 'returns what the script_compiler returns' do
        Puppet[:code] = <<-CODE
            42
          CODE
        expect(script_compiler.compile).to eql(42)
      end

      it 'referencing undefined variables raises an error' do
        expect do
          Puppet[:code] = <<-CODE
              notice $rubyversion
            CODE
            Puppet::Parser::ScriptCompiler.new(env, 'test_node_name').compile

        end.to raise_error(/Unknown variable: 'rubyversion'/)
      end

      it 'has strict=error behavior' do
        expect do
          Puppet[:code] = <<-CODE
              notice({a => 10, a => 20})
            CODE
            Puppet::Parser::ScriptCompiler.new(env, 'test_node_name').compile

        end.to raise_error(/The key 'a' is declared more than once/)
      end

      it 'performing a multi assign from a class reference raises an error' do
        expect do
          Puppet[:code] = <<-CODE
              [$a] = Class[the_dalit]
            CODE
            Puppet::Parser::ScriptCompiler.new(env, 'test_node_name').compile

        end.to raise_error(/The catalog operation 'multi var assignment from class' is only available when compiling a catalog/)
      end
    end

    context 'when using environment manifest' do
      context 'set to single file' do
        let (:manifest) { "#{env_dir}/manifests/good.pp" }

        it 'loads and evaluates' do
          expect(script_compiler.compile).to eql('good')
        end
      end

      context 'set to directory' do
        let (:manifest) { "#{env_dir}/manifests" }

        it 'fails with an error' do
          expect{script_compiler.compile}.to raise_error(/manifest of environment 'testenv' appoints directory '.*\/manifests'. It must be a file/)
        end
      end

      context 'set to non existing path' do
        let (:manifest) { "#{env_dir}/manyfiests/good.pp" }

        it 'fails with an error' do
          expect{script_compiler.compile}.to raise_error(/manifest of environment 'testenv' appoints '.*\/good.pp'. It does not exist/)
        end
      end
    end
  end
end
