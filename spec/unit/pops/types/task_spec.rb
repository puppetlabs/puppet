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

        it 'loads task as a GenericTask subtype' do
          compile do
            module_loader = Puppet.lookup(:loaders).find_loader('testmodule')
            task_t = module_loader.load(:type, 'testmodule::hello')
            expect(task_t).to be_a(Puppet::Pops::Types::PObjectType)
            expect(task_t.name).to eq('Testmodule::Hello')
            expect(task_t.parent.name).to eq('GenericTask')

            task = task_t.create('foo' => 'the foo', 'fee' => 311, 'fum' => false)
            expect(task).to be_a(Puppet::Pops::Types::Task)
            expect(task.executable_path).to eql("#{modules_dir}/testmodule/tasks/hello")
            expect(task.task_json).to eql('{"foo":"the foo","fee":311,"fum":false}')
            expect(task.task_args).to eql({"foo" => "the foo", "fee"=> 311, "fum" => false})
          end
        end

        it 'evaluator loads and notices an empty GenericTask without parameters' do
          compile(<<-PUPPET.unindent)
            notice(Testmodule::Hello())
          PUPPET
          expect(notices).to eql(["Testmodule::Hello({})"])
        end

        it 'evaluator loads and notices an empty GenericTask using {}' do
          compile(<<-PUPPET.unindent)
            notice(Testmodule::Hello({}))
          PUPPET
          expect(notices).to eql(["Testmodule::Hello({})"])
        end

        it 'evaluator loads and notices a GenericTask with parameters' do
          compile(<<-PUPPET.unindent)
            notice(Testmodule::Hello({foo => 'the foo', fee => 311, fum => false}))
          PUPPET
          expect(notices).to eql(["Testmodule::Hello({'foo' => 'the foo', 'fee' => 311, 'fum' => false})"])
        end

        context 'without --tasks' do
          before(:each) { Puppet[:tasks] = false }

          it 'evaluator does not recognize generic tasks' do
            expect{compile(<<-PUPPET.unindent)}.to raise_error(/Resource type not found: Testmodule::Hello/)
              notice(Testmodule::Hello())
            PUPPET
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
            'hello.json' => <<-JSON
            {
              "supports_noop": true,
              "parameters": {
                 "message": {
                   "type": "String"
                 },
                 "font": {
                   "type": "Optional[String]"
                 }
            }}
            JSON
            }
          }
        }

        it 'loads a task with parameters as a Task subtype' do
          compile do
            module_loader = Puppet.lookup(:loaders).find_loader('testmodule')
            task_t = module_loader.load(:type, 'testmodule::hello')
            expect(task_t).to be_a(Puppet::Pops::Types::PObjectType)
            expect(task_t.name).to eq('Testmodule::Hello')
            expect(task_t.parent.name).to eq('Task')

            expect(task_t['message']).to be_a(Puppet::Pops::Types::PObjectType::PAttribute)
            expect(task_t['message'].type).to be_a(Puppet::Pops::Types::PStringType)
            expect(task_t['supports_noop']).to be_a(Puppet::Pops::Types::PObjectType::PAttribute)
            expect(task_t['supports_noop'].type).to be_a(Puppet::Pops::Types::PBooleanType)
            expect(task_t['supports_noop'].kind).to eql('constant')
            expect(task_t['supports_noop'].value).to eql(true)

            task = task_t.create('a message')
            expect(task).to be_a(Puppet::Pops::Types::Task)
            expect(task.executable_path).to eql("#{modules_dir}/testmodule/tasks/hello.rb")
            expect(task.task_json).to eql('{"message":"a message"}')
            expect(task.task_args).to eql({"message" => "a message"})
          end
        end

        it 'evaluator loads and notices a Task with positional parameters' do
          compile(<<-PUPPET.unindent)
            notice(Testmodule::Hello('a message'))
          PUPPET
          expect(notices).to eql(["Testmodule::Hello({'message' => 'a message'})"])
        end

        it 'evaluator loads and notices a Task with positional parameters' do
          compile(<<-PUPPET.unindent)
            notice(Testmodule::Hello('a message', 'helvetica'))
          PUPPET
          expect(notices).to eql(["Testmodule::Hello({'message' => 'a message', 'font' => 'helvetica'})"])
        end

        it 'evaluator fails on invalid number of parameters' do
          expect { compile(<<-PUPPET.unindent) }.to raise_error(/expects between 1 and 2 arguments, got 3/)
            notice(Testmodule::Hello('a message', 'helvetica', 'bold'))
          PUPPET
        end

        it 'evaluator loads and notices a Task with named parameters' do
          compile(<<-PUPPET.unindent)
            notice(Testmodule::Hello({message => 'a message'}))
          PUPPET
          expect(notices).to eql(["Testmodule::Hello({'message' => 'a message'})"])
        end

        it 'evaluator fails on invalid parameter names' do
          expect { compile(<<-PUPPET.unindent) }.to raise_error(/expects a value for key 'message'.*unrecognized key 'echo'/m)
            notice(Testmodule::Hello({echo => 'a message'}))
          PUPPET
        end

        context 'without --tasks' do
          before(:each) { Puppet[:tasks] = false }

          it 'evaluator does not recognize generic tasks' do
            expect{compile(<<-PUPPET.unindent)}.to raise_error(/Resource type not found: Testmodule::Hello/)
              notice(Testmodule::Hello('a message'))
              PUPPET
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

          it 'loads a task with parameters as a Task subtype' do
            compile do
              module_loader = Puppet.lookup(:loaders).find_loader('testmodule')
              expect{module_loader.load(:type, 'testmodule::hello')}.to raise_error(
                /The metadata for task testmodule::hello has wrong type, unrecognized key 'supports_nop'/)
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

          it 'loads a task with parameters as a Task subtype' do
            compile do
              module_loader = Puppet.lookup(:loaders).find_loader('testmodule')
              expect{module_loader.load(:type, 'testmodule::hello')}.to raise_error(
                /entry 'parameters' key of entry 'Message' expects a match for Pattern\[\/\\A\[a-z\]\[a-z0-9_\]\*\\z\/\], got 'Message'/)
            end
          end
        end
      end

      context 'with defined type' do
        let(:testmodule) {
          {
            'tasks' => {
              'hello.rb' => <<-RUBY,
            require 'json'
            args = JSON.parse(STDIN.read)
            puts({message: args['message']}.to_json)
            exit 0
            RUBY
            },
            'types' => {
              'hello.pp' => <<-PUPPET
            type Testmodule::Hello = Task {
              constants => {
                supports_noop => true,
                executable => 'hello.rb'
              },
              attributes => {
                message => String,
                font => {
                  type => Optional[String],
                  value => undef
                }
              }
            }
            PUPPET
            }
          }
        }

        it 'loads a task defined as a Type' do
          compile do
            module_loader = Puppet.lookup(:loaders).find_loader('testmodule')
            task_t = module_loader.load(:type, 'testmodule::hello').resolve(module_loader)
            expect(task_t).to be_a(Puppet::Pops::Types::PObjectType)
            expect(task_t.name).to eq('Testmodule::Hello')
            task = task_t.create('a message')
            expect(task.executable_path).to eql("#{modules_dir}/testmodule/tasks/hello.rb")
          end
        end

        it 'evaluator loads and notices a Task with named parameters' do
          compile(<<-PUPPET.unindent)
            notice(Testmodule::Hello({message => 'a message'}))
            PUPPET
          expect(notices).to eql(["Testmodule::Hello({'message' => 'a message'})"])
        end

        context 'without --tasks' do
          before(:each) { Puppet[:tasks] = false }

          it 'evaluator fails to load Task' do
            expect { compile(<<-PUPPET.unindent) }.to raise_error(/unresolved type 'Task'/)
            notice(Testmodule::Hello({message => 'a message'}))
            PUPPET
          end
        end
      end
    end
  end

  it 'can present itself as json' do
    Puppet[:tasks] = true

    code = <<-PUPPET.unindent
    
      type Service::Action = Enum[
        # Start the service
        'start',
        # Stop the service,
        'stop',
        # Restart the service
        'restart',
        # Ensure that the service is enabled
        'enable',
        # Disable the service
        'disable',
        # Report the current status of the service
        'Status'
      ]

      # @summary Manage and inspect the state of services
      # @parameter action The operation (start, stop, restart, enable, disable, status) to perform on the service
      # @parameter service The name of the service to install
      # @parameter provider The provider to use to manage or inspect the service, defaults to the system service manager
      type Service::Init = Task {
        constants => {
          supports_noop => true,
          input_format => 'stdin:json'
        },
        attributes => {
          action => Service::Action,
          service => String[1],
          provider => {
            type => String[1],
            value => 'system'
          }
        }
      }
      notice(Service::Init('restart', 'httpd').task_json())
    PUPPET
    expect(eval_and_collect_notices(code)[0]).to eql('{"action":"restart","service":"httpd"}')
  end
end
end
end

