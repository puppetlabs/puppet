require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'
require 'puppet/parser/script_compiler'

module Puppet::Pops
module Types
describe 'The Task Type' do
  include PuppetSpec::Compiler
  include PuppetSpec::Files

  context 'when loading' do
    let(:testing_env) do
      {
        'testing' => {
          'modules' => modules,
          'manifests' => manifests
        }
      }
    end

    let(:manifests) { {} }
    let(:environments_dir) { Puppet[:environmentpath] }

    let(:testing_env_dir) do
      dir_contained_in(environments_dir, testing_env)
      env_dir = File.join(environments_dir, 'testing')
      PuppetSpec::Files.record_tmp(env_dir)
      env_dir
    end

    let(:modules_dir) { File.join(testing_env_dir, 'modules') }
    let(:env) { Puppet::Node::Environment.create(:testing, [modules_dir]) }
    let(:node) { Puppet::Node.new('test', :environment => env) }
    let(:logs) { [] }
    let(:warnings) { logs.select { |log| log.level == :warning }.map { |log| log.message } }
    let(:notices) { logs.select { |log| log.level == :notice }.map { |log| log.message } }
    let(:task_t) { TypeFactory.task }
    before(:each) { Puppet[:tasks] = true }

    context 'tasks' do
      let(:compiler) { Puppet::Parser::ScriptCompiler.new(env, node.name) }

      let(:modules) do
        { 'testmodule' => testmodule }
      end

      def compile(code = nil)
        Puppet[:code] = code
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          compiler.compile do |catalog|
            yield if block_given?
            catalog
          end
        end
      end

      context 'without metadata' do
        let(:testmodule) {
          {
            'tasks' => {
              'hello' => <<-RUBY
            require 'json'
            args = JSON.parse(STDIN.read)
            puts({message: args['message']}.to_json)
            exit 0
            RUBY
            }
          }
        }

        it 'loads task without metadata as a generic Task' do
          compile do
            module_loader = Puppet.lookup(:loaders).find_loader('testmodule')
            task = module_loader.load(:task, 'testmodule::hello')
            expect(task_t.instance?(task)).to be_truthy
            expect(task.name).to eq('testmodule::hello')
            expect(task._pcore_type).to eq(task_t)
          end
        end

        context 'without --tasks' do
          before(:each) { Puppet[:tasks] = false }

          it 'evaluator does not recognize generic tasks' do
            compile do
              module_loader = Puppet.lookup(:loaders).find_loader('testmodule')
              expect(module_loader.load(:task, 'testmodule::hello')).to be_nil
            end
          end
        end
      end

      context 'with metadata' do
        let(:testmodule) {
          {
            'tasks' => {
              'hello.rb' => <<-RUBY,
                require 'json'
                args = JSON.parse(STDIN.read)
                puts({message: args['message']}.to_json)
                exit 0
                RUBY
              'hello.json' => <<-JSON,
                {
                  "puppet_task_version": 1,
                  "supports_noop": true,
                  "parameters": {
                     "message": {
                       "type": "String",
                       "description": "the message",
                       "sensitive": false
                     },
                     "font": {
                       "type": "Optional[String]"
                     }
                }}
                JSON
              'non_data.rb' => <<-RUBY,
                require 'json'
                args = JSON.parse(STDIN.read)
                puts({message: args['message']}.to_json)
                exit 0
                RUBY
              'non_data.json' => <<-JSON
                {
                  "puppet_task_version": 1,
                  "supports_noop": true,
                  "parameters": {
                     "arg": {
                       "type": "Hash",
                       "description": "the non data param"
                     }
                }}
                JSON
            }
          }
        }

        it 'loads a task with parameters' do
          compile do
            module_loader = Puppet.lookup(:loaders).find_loader('testmodule')
            task = module_loader.load(:task, 'testmodule::hello')
            expect(task_t.instance?(task)).to be_truthy
            expect(task.name).to eq('testmodule::hello')
            expect(task._pcore_type).to eq(task_t)
            expect(task.supports_noop).to eql(true)
            expect(task.puppet_task_version).to eql(1)
            expect(task.executable).to eql("#{modules_dir}/testmodule/tasks/hello.rb")

            tp = task.parameters
            expect(tp['message']['description']).to eql('the message')
            expect(tp['message']['type']).to be_a(Puppet::Pops::Types::PStringType)
          end
        end

        it 'loads a task with non-Data parameter' do
          compile do
            module_loader = Puppet.lookup(:loaders).find_loader('testmodule')
            task = module_loader.load(:task, 'testmodule::non_data')
            expect(task_t.instance?(task)).to be_truthy
            tp = task.parameters
            expect(tp['arg']['type']).to be_a(Puppet::Pops::Types::PHashType)
          end
        end

        context 'with adjacent directory for init task' do
          let(:testmodule) {
            {
              'tasks' => {
                'init' => {
                  'foo.sh' => 'echo hello'
                },
                'init.sh' => 'echo hello',
                'init.json' => <<-JSON
                {
                  "supports_noop": true,
                  "parameters": {
                     "message": { "type": "String" }
                  }
                }
              JSON
              }
            }
          }

          it 'loads the init task with parameters and executable' do
            compile do
              module_loader = Puppet.lookup(:loaders).find_loader('testmodule')
              task = module_loader.load(:task, 'testmodule')
              expect(task_t.instance?(task)).to be_truthy
              expect(task.executable).to eql("#{modules_dir}/testmodule/tasks/init.sh")
              expect(task.parameters).to be_a(Hash)
              expect(task.parameters['message']['type']).to be_a(Puppet::Pops::Types::PStringType)
            end
          end
        end

        context 'with adjacent directory for named task' do
          let(:testmodule) {
            {
              'tasks' => {
                'hello' => {
                  'foo.sh' => 'echo hello'
                },
                'hello.sh' => 'echo hello',
                'hello.json' => <<-JSON
                {
                  "supports_noop": true,
                  "parameters": {
                     "message": { "type": "String" }
                  }
                }
              JSON
              }
            }
          }

          it 'loads a named task with parameters and executable' do
            compile do
              module_loader = Puppet.lookup(:loaders).find_loader('testmodule')
              task = module_loader.load(:task, 'testmodule::hello')
              expect(task_t.instance?(task)).to be_truthy
              expect(task.executable).to eql("#{modules_dir}/testmodule/tasks/hello.sh")
              expect(task.parameters).to be_a(Hash)
              expect(task.parameters['message']['type']).to be_a(Puppet::Pops::Types::PStringType)
            end
          end
        end

        context 'using more than two segments in the name' do
          let(:testmodule) {
            {
              'tasks' => {
                'hello' => {
                  'foo.sh' => 'echo hello'
                }
              }
            }
          }

          it 'task is not found' do
            compile do
              module_loader = Puppet.lookup(:loaders).find_loader('testmodule')
              expect(module_loader.load(:task, 'testmodule::hello::foo')).to be_nil
            end
          end
        end

        context 'that has a malformed top-level entry' do
          let(:testmodule) {
            {
              'tasks' => {
                'hello' => 'echo hello',
                'hello.json' => <<-JSON
                {
                  "supports_nop": true,
                  "parameters": {
                     "message": { "type": "String" }
                  }
                }
              JSON
              }
            }
          }

          it 'fails with unrecognized key error' do
            compile do
              module_loader = Puppet.lookup(:loaders).find_loader('testmodule')
              expect{module_loader.load(:task, 'testmodule::hello')}.to raise_error(
                /Failed to load metadata for task testmodule::hello:.*unrecognized key 'supports_nop'/)
            end
          end
        end

        context 'that has no parameters' do
          let(:testmodule) {
            {
              'tasks' => {
                'hello' => 'echo hello',
                'hello.json' => '{ "supports_noop": false }'             }
            }
          }

          it 'loads the task with parameters set to undef' do
            compile do
              module_loader = Puppet.lookup(:loaders).find_loader('testmodule')
              task = module_loader.load(:task, 'testmodule::hello')
              expect(task_t.instance?(task)).to be_truthy
              expect(task.parameters).to be_nil
            end
          end
        end

        context 'that has a malformed parameter name' do
          let(:testmodule) {
            {
              'tasks' => {
                'hello' => 'echo hello',
                'hello.json' => <<-JSON
                {
                  "supports_noop": true,
                  "parameters": {
                     "Message": { "type": "String" }
                  }
                }
              JSON
              }
            }
          }

          it 'fails with pattern mismatch error' do
            compile do
              module_loader = Puppet.lookup(:loaders).find_loader('testmodule')
              expect{module_loader.load(:task, 'testmodule::hello')}.to raise_error(
                /entry 'parameters' key of entry 'Message' expects a match for Pattern\[\/\\A\[a-z\]\[a-z0-9_\]\*\\z\/\], got 'Message'/)
            end
          end
        end

        context 'that has a puppet_task_version that is a string' do
          let(:testmodule) {
            {
              'tasks' => {
                'hello' => 'echo hello',
                'hello.json' => <<-JSON
                {
                  "puppet_task_version": "1",
                  "supports_noop": true,
                  "parameters": {
                     "message": { "type": "String" }
                  }
                }
              JSON
              }
            }
          }

          it 'fails with type mismatch error' do
            compile do
              module_loader = Puppet.lookup(:loaders).find_loader('testmodule')
              expect{module_loader.load(:task, 'testmodule::hello')}.to raise_error(
                /entry 'puppet_task_version' expects an Integer value, got String/)
            end
          end
        end
      end
    end
  end
end
end
end

