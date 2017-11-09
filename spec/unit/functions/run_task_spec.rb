require 'spec_helper'
require 'puppet/pops'
require 'puppet/loaders'
require 'puppet_spec/compiler'

describe 'the run_task function' do
  include PuppetSpec::Compiler
  include PuppetSpec::Files

  before(:each) do
    Puppet[:tasks] = true
    loaders = Puppet::Pops::Loaders.new(env)
    Puppet.push_context({:loaders => loaders}, "test-examples")
  end

  around(:each) do |example|
    Puppet.override(:bolt_executor => executor) do
      example.run
    end
  end

  after(:each) do
    Puppet::Pops::Loaders.clear
    Puppet::pop_context()
  end

  let(:executor) { mock('bolt_executor') }
  let(:env_name) { 'testenv' }
  let(:environments_dir) { Puppet[:environmentpath] }
  let(:env_dir) { File.join(environments_dir, env_name) }
  let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(populated_env_dir, 'modules')]) }
  let(:node) { Puppet::Node.new("test", :environment => env) }
  let(:env_dir_files) {
    {
      'modules' => {
        'test' => {
          'tasks' => {
            'echo.sh' => 'echo -n "$PT_message"',
            'meta.sh' => 'echo -n "$PT_message"',
            'meta.json' => '{"description": "echo a message", "input_method": "environment", "parameters": {"message": {"description": "the message", "type": "String"}}}',
            'yes.sh' => 'echo -n "yes"',
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
  let(:func) { Puppet.lookup(:loaders).puppet_system_loader.load(:function, 'run_task') }

  context 'it calls bolt with executor, input method, and arguments' do
    let(:hostname) { 'a.b.com' }
    let(:hostname2) { 'x.y.com' }
    let(:message) { 'the message' }
    let(:hosts) { [hostname] }
    let(:host) { stub(uri: hostname) }
    let(:host2) { stub(uri: hostname2) }
    let(:result) { { value: message } }

    before(:each) do
      Puppet.features.stubs(:bolt?).returns(true)
    end

    it 'when running a task without metadata the input method is "both"' do
      executable = File.join(env_dir, 'modules/test/tasks/echo.sh')

      executor.expects(:from_uris).with(hosts).returns([host])
      executor.expects(:run_task).with([host], executable, 'both', {'message' => 'the message'}).returns({ host => result })
      result.expects(:to_h).returns(result)

      expect(eval_and_collect_notices(<<-CODE, node)).to eql(["ExecutionResult({'#{hostname}' => {value => '#{message}'}})"])
        $a = run_task(Test::Echo({message => "#{message}"}), "#{hostname}")
        notice $a
      CODE
    end

    it 'when running a task with metadata - the input method is specified by the metadata' do
      executable = File.join(env_dir, 'modules/test/tasks/meta.sh')

      executor.expects(:from_uris).with(hosts).returns([host])
      executor.expects(:run_task).with([host], executable, 'environment', {'message' => 'the message'}).returns({ host => result })
      result.expects(:to_h).returns(result)

      expect(eval_and_collect_notices(<<-CODE, node)).to eql(["ExecutionResult({'#{hostname}' => {value => '#{message}'}})"])
        $a = run_task(Test::Meta({message => "#{message}"}), "#{hostname}")
        notice $a
      CODE
    end

    it 'nodes can be specified as repeated nested arrays and strings and combine into one list of nodes' do
      executable = File.join(env_dir, 'modules/test/tasks/meta.sh')

      executor.expects(:from_uris).with([hostname, hostname2]).returns([host, host2])
      executor.expects(:run_task).with([host, host2], executable, 'environment', {'message' => 'the message'}).returns(
        { host => result, host2 => result })
      result.expects(:to_h).twice.returns(result)

      expect(eval_and_collect_notices(<<-CODE, node)).to eql(["ExecutionResult({'#{hostname}' => {value => '#{message}'}, '#{hostname2}' => {value => '#{message}'}})"])
        $a = run_task(Test::Meta({message => "#{message}"}), "#{hostname}", [["#{hostname2}"]],[])
        notice $a
      CODE
    end

    it 'nodes can be specified as repeated nested arrays and Targets and combine into one list of nodes' do
      executable = File.join(env_dir, 'modules/test/tasks/meta.sh')

      executor.expects(:from_uris).with([hostname, hostname2]).returns([host, host2])
      executor.expects(:run_task).with([host, host2], executable, 'environment', {'message' => 'the message'}).returns(
        { host => result, host2 => result })
      result.expects(:to_h).twice.returns(result)

      expect(eval_and_collect_notices(<<-CODE, node)).to eql(["ExecutionResult({'#{hostname}' => {value => '#{message}'}, '#{hostname2}' => {value => '#{message}'}})"])
        $a = run_task(Test::Meta({message => "#{message}"}), Target('#{hostname}'), [[Target('#{hostname2}')]],[])
        notice $a
      CODE
    end

    context 'the same way as if a task instance was used; when called with'
      context 'a task type' do
        it 'and args hash' do
          executable = File.join(env_dir, 'modules/test/tasks/meta.sh')

          executor.expects(:from_uris).with(hosts).returns([host])
          executor.expects(:run_task).with([host], executable, 'environment', {'message' => 'the message'}).returns({ host => result })
          result.expects(:to_h).returns(result)

          expect(eval_and_collect_notices(<<-CODE, node)).to eql(["ExecutionResult({'#{hostname}' => {value => '#{message}'}})"])
            $a = run_task(Test::Meta, "#{hostname}", {message => "#{message}"})
            notice $a
          CODE
        end

        it 'without args hash (for a task where this is allowed)' do
          executable = File.join(env_dir, 'modules/test/tasks/yes.sh')

          executor.expects(:from_uris).with(hosts).returns([host])
          executor.expects(:run_task).with([host], anything, 'both', {}).returns({ host => result })
          result.expects(:to_h).returns(result)

          expect(eval_and_collect_notices(<<-CODE, node)).to eql(["ExecutionResult({'#{hostname}' => {value => '#{message}'}})"])
            $a = run_task(Test::Yes, "#{hostname}")
            notice $a
          CODE
        end

        it 'without nodes - does not invoke bolt' do
          executable = File.join(env_dir, 'modules/test/tasks/yes.sh')

          executor.expects(:from_uris).never
          executor.expects(:run_task).never

          expect(eval_and_collect_notices(<<-CODE, node)).to eql(['ExecutionResult({})'])
            $a = run_task(Test::Yes, [])
            notice $a
          CODE
        end
      end

    context 'a task name' do
      it 'and args hash' do
        executable = File.join(env_dir, 'modules/test/tasks/meta.sh')

        executor.expects(:from_uris).with(hosts).returns([host])
        executor.expects(:run_task).with([host], executable, 'environment', {'message' => 'the message'}).returns({ host => result })
        result.expects(:to_h).returns(result)

        expect(eval_and_collect_notices(<<-CODE, node)).to eql(["ExecutionResult({'#{hostname}' => {value => '#{message}'}})"])
          $a = run_task('test::meta', "#{hostname}", {message => "#{message}"})
          notice $a
        CODE
      end

      it 'without args hash (for a task where this is allowed)' do
        executable = File.join(env_dir, 'modules/test/tasks/yes.sh')

        executor.expects(:from_uris).with(hosts).returns([host])
        executor.expects(:run_task).with([host], executable, 'both', {}).returns({ host => result })
        result.expects(:to_h).returns(result)

        expect(eval_and_collect_notices(<<-CODE, node)).to eql(["ExecutionResult({'#{hostname}' => {value => '#{message}'}})"])
          $a = run_task('test::yes', "#{hostname}")
          notice $a
        CODE
      end

      it 'without nodes - does not invoke bolt' do
        executable = File.join(env_dir, 'modules/test/tasks/yes.sh')

        executor.expects(:from_uris).never
        executor.expects(:run_task).never

        expect(eval_and_collect_notices(<<-CODE, node)).to eql(['ExecutionResult({})'])
          $a = run_task('test::yes', [])
          notice $a
        CODE
      end

      it 'with non existing task - reports an unknown task error' do
        expect{eval_and_collect_notices(<<-CODE, node)}.to raise_error(/Task not found: test::nonesuch/)
          run_task('test::nonesuch', [])
        CODE
      end

      it 'with name of puppet runtime type - reports an unknown task error' do
        expect{eval_and_collect_notices(<<-CODE, node)}.to raise_error(/Task not found: package/)
          run_task(package, [])
        CODE
      end

      context 'on a module that contains manifests/init.pp' do
        let(:env_dir_files) {
          {
            'modules' => {
              'test' => {
                'manifests' => {
                  'init.pp' => 'class test ? this is not valid puppet ?'
                },
                'tasks' => {
                  'echo.sh' => 'echo -n "$PT_message"',
                }
              }
            }
          }
        }

        it 'the call does not load init.pp' do
          executor.expects(:from_uris).never
          executor.expects(:run_task).never

          expect(eval_and_collect_notices(<<-CODE, node)).to eql(['ok'])
          run_task('test::echo', [])
          notice ok
          CODE
        end
      end

      context 'on a module that contains tasks/init.sh' do
        let(:env_dir_files) {
          {
            'modules' => {
              'test' => {
                'tasks' => {
                  'init.sh' => 'echo -n "$PT_message"',
                }
              }
            }
          }
        }

        it 'finds task named after the module' do
          executable = File.join(env_dir, 'modules/test/tasks/init.sh')

          executor.expects(:from_uris).with(hosts).returns([host])
          executor.expects(:run_task).with([host], executable, 'both', {}).returns({ host => result })
          result.expects(:to_h).returns(result)

          expect(eval_and_collect_notices(<<-CODE, node)).to eql(["ExecutionResult({'#{hostname}' => {value => '#{message}'}})"])
          $a = run_task('test', "#{hostname}")
          notice $a
          CODE
        end
      end
    end
  end
end
