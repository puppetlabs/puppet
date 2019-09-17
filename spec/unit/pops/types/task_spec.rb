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
    before(:each) { Puppet.push_context({tasks: true}) }

    context 'tasks' do
      let(:compiler) { Puppet::Parser::ScriptCompiler.new(env, node.name) }

      let(:modules) do
        { 'testmodule' => testmodule }
      end

      let(:module_loader) { Puppet.lookup(:loaders).find_loader('testmodule') }

      def compile(code = '')
        Puppet.push_context({code: code})
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
            task = module_loader.load(:task, 'testmodule::hello')
            expect(task_t.instance?(task)).to be_truthy
            expect(task.name).to eq('testmodule::hello')
            expect(task._pcore_type).to eq(task_t)
          end
        end

        context 'without --tasks' do
          before(:each) { Puppet.push_context({tasks: false}) }

          it 'evaluator does not recognize generic tasks' do
            compile do
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
            task = module_loader.load(:task, 'testmodule::hello')
            expect(task_t.instance?(task)).to be_truthy
            expect(task.name).to eq('testmodule::hello')
            expect(task._pcore_type).to eq(task_t)
            expect(task.metadata['supports_noop']).to eql(true)
            expect(task.metadata['puppet_task_version']).to eql(1)
            expect(task.files).to eql([{"name" => "hello.rb", "path" => "#{modules_dir}/testmodule/tasks/hello.rb"}])

            expect(task.metadata['parameters']['message']['description']).to eql('the message')
            expect(task.parameters['message']).to be_a(Puppet::Pops::Types::PStringType)
          end
        end

        it 'loads a task with non-Data parameter' do
          compile do
            task = module_loader.load(:task, 'testmodule::non_data')
            expect(task_t.instance?(task)).to be_truthy
            expect(task.parameters['arg']).to be_a(Puppet::Pops::Types::PHashType)
          end
        end

        context 'without an implementation file' do
          let(:testmodule) {
            {
              'tasks' => {
                'init.json' => '{}'
              }
            }
          }

          it 'fails to load the task' do
            compile do
              expect {
                module_loader.load(:task, 'testmodule')
              }.to raise_error(Puppet::Module::Task::InvalidTask, /No source besides task metadata was found/)
            end
          end
        end

        context 'with multiple implementation files' do
          let(:metadata) { '{}' }
          let(:testmodule) {
            {
              'tasks' => {
                'init.sh' => '',
                'init.ps1' => '',
                'init.json' => metadata,
              }
            }
          }

          it "fails if metadata doesn't specify implementations" do
            compile do
              expect {
                module_loader.load(:task, 'testmodule')
              }.to raise_error(Puppet::Module::Task::InvalidTask, /Multiple executables were found .*/)
            end
          end

          it "returns the implementations if metadata lists them all" do
            impls = [{'name' => 'init.sh', 'requirements' => ['shell']},
                     {'name' => 'init.ps1', 'requirements' => ['powershell']}]
            metadata.replace({'implementations' => impls}.to_json)

            compile do
              task = module_loader.load(:task, 'testmodule')
              expect(task_t.instance?(task)).to be_truthy
              expect(task.files).to eql([
                {"name" => "init.sh", "path" => "#{modules_dir}/testmodule/tasks/init.sh"},
                {"name" => "init.ps1", "path" => "#{modules_dir}/testmodule/tasks/init.ps1"}
              ])
              expect(task.metadata['implementations']).to eql([
                {"name" => "init.sh", "requirements" => ['shell']},
                {"name" => "init.ps1", "requirements" => ['powershell']}
              ])
            end
          end

          it "returns a single implementation if metadata only specifies one implementation" do
            impls = [{'name' => 'init.ps1', 'requirements' => ['powershell']}]
            metadata.replace({'implementations' => impls}.to_json)

            compile do
              task = module_loader.load(:task, 'testmodule')
              expect(task_t.instance?(task)).to be_truthy
              expect(task.files).to eql([
                {"name" => "init.ps1", "path" => "#{modules_dir}/testmodule/tasks/init.ps1"}
              ])
              expect(task.metadata['implementations']).to eql([
                {"name" => "init.ps1", "requirements" => ['powershell']}
              ])
            end
          end

          it "fails if a specified implementation doesn't exist" do
            impls = [{'name' => 'init.sh', 'requirements' => ['shell']},
                     {'name' => 'init.ps1', 'requirements' => ['powershell']},
                     {'name' => 'init.rb', 'requirements' => ['puppet-agent']}]
            metadata.replace({'implementations' => impls}.to_json)

            compile do
              expect {
                module_loader.load(:task, 'testmodule')
              }.to raise_error(Puppet::Module::Task::InvalidTask, /Task metadata for task testmodule specifies missing implementation init\.rb/)
            end
          end

          it "fails if the implementations key isn't an array" do
            metadata.replace({'implementations' => {'init.rb' => []}}.to_json)

            compile do
              expect {
                module_loader.load(:task, 'testmodule')
              }.to raise_error(Puppet::Module::Task::InvalidMetadata, /Task metadata for task testmodule does not specify implementations as an array/)
            end
          end
        end

        context 'with multiple tasks sharing executables' do
          let(:foo_metadata) { '{}' }
          let(:bar_metadata) { '{}' }
          let(:testmodule) {
            {
              'tasks' => {
                'foo.sh' => '',
                'foo.ps1' => '',
                'foo.json' => foo_metadata,
                'bar.json' => bar_metadata,
                'baz.json' => bar_metadata,
              }
            }
          }

          it 'loads a task that uses executables named after another task' do
            metadata = {
              implementations: [
                {name: 'foo.sh', requirements: ['shell']},
                {name: 'foo.ps1', requirements: ['powershell']},
              ]
            }
            bar_metadata.replace(metadata.to_json)

            compile do
              task = module_loader.load(:task, 'testmodule::bar')
              expect(task.files).to eql([
                {'name' => 'foo.sh', 'path' => "#{modules_dir}/testmodule/tasks/foo.sh"},
                {'name' => 'foo.ps1', 'path' => "#{modules_dir}/testmodule/tasks/foo.ps1"},
              ])
            end
          end

          it 'fails to load the task if it has no implementations section and no associated executables' do
            compile do
              expect {
                module_loader.load(:task, 'testmodule::bar')
              }.to raise_error(Puppet::Module::Task::InvalidTask, /No source besides task metadata was found/)
            end
          end

          it 'fails to load the task if it has no files at all' do
            compile do
              expect(module_loader.load(:task, 'testmodule::qux')).to be_nil
            end
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

          it 'loads the init task with parameters and implementations' do
            compile do
              task = module_loader.load(:task, 'testmodule')
              expect(task_t.instance?(task)).to be_truthy
              expect(task.files).to eql([{"name" => "init.sh", "path" => "#{modules_dir}/testmodule/tasks/init.sh"}])
              expect(task.metadata['parameters']).to be_a(Hash)
              expect(task.parameters['message']).to be_a(Puppet::Pops::Types::PStringType)
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

          it 'loads a named task with parameters and implementations' do
            compile do
              task = module_loader.load(:task, 'testmodule::hello')
              expect(task_t.instance?(task)).to be_truthy
              expect(task.files).to eql([{"name" => "hello.sh", "path" => "#{modules_dir}/testmodule/tasks/hello.sh"}])
              expect(task.metadata['parameters']).to be_a(Hash)
              expect(task.parameters['message']).to be_a(Puppet::Pops::Types::PStringType)
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
              expect(module_loader.load(:task, 'testmodule::hello::foo')).to be_nil
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
              task = module_loader.load(:task, 'testmodule::hello')
              expect(task_t.instance?(task)).to be_truthy
              expect(task.metadata['parameters']).to be_nil
            end
          end
        end
      end
    end
  end
end
end
end

