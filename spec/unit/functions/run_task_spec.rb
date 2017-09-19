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

  after(:each) do
    Puppet::Pops::Loaders.clear
    Puppet::pop_context()
  end

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
    let(:message) { 'the message' }
    let(:hosts) { [hostname] }
    let(:host) { stub(uri: hostname) }
    let(:result) { stub(output_string: message, success?: true) }
    before(:each) do
      Puppet.features.stubs(:bolt?).returns(true)
      module ::Bolt; end
      class ::Bolt::Executor; end
    end

    it 'when running a task without metadata the input method is "both"' do
      executor = mock('executor')
      executable = File.join(env_dir, 'modules/test/tasks/echo.sh')

      Bolt::Executor.expects(:from_uris).with(hosts).returns(executor)
      executor.expects(:run_task).with(executable, 'both', {'message' => 'the message'}).returns({ host => result })

      expect(eval_and_collect_notices(<<-CODE, node)).to eql(["[#{message}]"])
        $a = run_task(Test::Echo({message => "#{message}"}), "#{hostname}")
        notice $a
      CODE
    end

    it 'when running a task with metadata - the input method is specified by the metadata' do
      executor = mock('executor')
      executable = File.join(env_dir, 'modules/test/tasks/meta.sh')

      Bolt::Executor.expects(:from_uris).with(hosts).returns(executor)
      executor.expects(:run_task).with(executable, 'environment', {'message' => 'the message'}).returns({ host => result })

      expect(eval_and_collect_notices(<<-CODE, node)).to eql(["[#{message}]"])
        $a = run_task(Test::Meta({message => "#{message}"}), "#{hostname}")
        notice $a
      CODE
    end

    context 'the same way as if a task instance was used; when called with'
      context 'a task type' do
        it 'and args hash' do
          executor = mock('executor')
          executable = File.join(env_dir, 'modules/test/tasks/meta.sh')

          Bolt::Executor.expects(:from_uris).with(hosts).returns(executor)
          executor.expects(:run_task).with(executable, 'environment', {'message' => 'the message'}).returns({ host => result })

          expect(eval_and_collect_notices(<<-CODE, node)).to eql(["[#{message}]"])
            $a = run_task(Test::Meta, "#{hostname}", {message => "#{message}"})
            notice $a
          CODE
        end

        it 'without args hash (for a task where this is allowed)' do
          executor = mock('executor')
          executable = File.join(env_dir, 'modules/test/tasks/yes.sh')

          Bolt::Executor.expects(:from_uris).with(hosts).returns(executor)
          executor.expects(:run_task).with(executable, 'both', {}).returns({ host => result })

          expect(eval_and_collect_notices(<<-CODE, node)).to eql(["[#{message}]"])
            $a = run_task(Test::Yes, "#{hostname}")
            notice $a
          CODE
        end

        it 'without nodes - does not invoke bolt' do
          executor = mock('executor')
          executable = File.join(env_dir, 'modules/test/tasks/yes.sh')

          Bolt::Executor.expects(:from_uris).never
          executor.expects(:run_task).never

          expect(eval_and_collect_notices(<<-CODE, node)).to eql(["Undef"])
            $a = run_task(Test::Yes, [])
            notice type($a)
          CODE
        end
      end

    context 'a task name' do
      it 'and args hash' do
        executor = mock('executor')
        executable = File.join(env_dir, 'modules/test/tasks/meta.sh')

        Bolt::Executor.expects(:from_uris).with(hosts).returns(executor)
        executor.expects(:run_task).with(executable, 'environment', {'message' => 'the message'}).returns({ host => result })

        expect(eval_and_collect_notices(<<-CODE, node)).to eql(["[#{message}]"])
          $a = run_task('test::meta', "#{hostname}", {message => "#{message}"})
          notice $a
        CODE
      end

      it 'without args hash (for a task where this is allowed)' do
        executor = mock('executor')
        executable = File.join(env_dir, 'modules/test/tasks/yes.sh')

        Bolt::Executor.expects(:from_uris).with(hosts).returns(executor)
        executor.expects(:run_task).with(executable, 'both', {}).returns({ host => result })

        expect(eval_and_collect_notices(<<-CODE, node)).to eql(["[#{message}]"])
          $a = run_task('test::yes', "#{hostname}")
          notice $a
        CODE
      end

      it 'without nodes - does not invoke bolt' do
        executor = mock('executor')
        executable = File.join(env_dir, 'modules/test/tasks/yes.sh')

        Bolt::Executor.expects(:from_uris).never
        executor.expects(:run_task).never

        expect(eval_and_collect_notices(<<-CODE, node)).to eql(["Undef"])
          $a = run_task('test::yes', [])
          notice type($a)
        CODE
      end
    end

  end
end
