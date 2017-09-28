require 'spec_helper'
require 'puppet/pops'
require 'puppet/loaders'
require 'puppet_spec/compiler'

describe 'the run_command function' do
  include PuppetSpec::Compiler
  include PuppetSpec::Files

  let(:tasks_enabled) { true }
  let(:env_name) { 'testenv' }
  let(:environments_dir) { Puppet[:environmentpath] }
  let(:env_dir) { File.join(environments_dir, env_name) }
  let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(env_dir, 'modules')]) }
  let(:node) { Puppet::Node.new("test", :environment => env) }

  before(:each) do
    Puppet[:tasks] = tasks_enabled
    loaders = Puppet::Pops::Loaders.new(env)
    Puppet.push_context({:loaders => loaders}, "test-examples")
  end

  after(:each) do
    Puppet::Pops::Loaders.clear
    Puppet::pop_context()
  end

  let(:func) { Puppet.lookup(:loaders).puppet_system_loader.load(:function, 'run_command') }

  context 'it calls bolt executor run_command' do
    let(:hostname) { 'test.example.com' }
    let(:hosts) { [hostname] }
    let(:host) { stub(uri: hostname) }
    let(:command) { 'hostname' }
    let(:result) { stub(output_string: hostname, success?: true) }
    before(:each) do
      Puppet.features.stubs(:bolt?).returns(true)
      module ::Bolt; end
      class ::Bolt::Executor; end
    end

    it 'with given command and host' do
      executor = mock('executor')
      Bolt::Executor.expects(:from_uris).with(hosts).returns(executor)
      executor.expects(:run_command).with(command).returns({ host => result })

      expect(eval_and_collect_notices(<<-CODE, node)).to eql(["[#{hostname}]"])
        $a = run_command('#{command}', '#{hostname}')
        notice $a
      CODE
    end

    context 'with multiple hosts' do
      let(:hostname2) { 'test.testing.com' }
      let(:hosts) { [hostname, hostname2] }
      let(:host2) { stub(uri: hostname2) }
      let(:result2) { stub(output_string: hostname2, success?: true) }

      it 'with propagates multiple hosts and returns multiple results' do
        executor = mock('executor')
        Bolt::Executor.expects(:from_uris).with(hosts).returns(executor)
        executor.expects(:run_command).with(command).returns({ host => result, host2 => result2 })

        expect(eval_and_collect_notices(<<-CODE, node)).to eql(["[#{hostname}, #{hostname2}]"])
          $a = run_command('#{command}', '#{hostname}', '#{hostname2}')
          notice $a
        CODE
      end
    end

    it 'without nodes - does not invoke bolt' do
      executor = mock('executor')
      Bolt::Executor.expects(:from_uris).never
      executor.expects(:run_command).never

      expect(eval_and_collect_notices(<<-CODE, node)).to eql(['[]'])
        $a = run_command('#{command}')
        notice $a
      CODE
    end
  end

  context 'without bolt feature present' do
    it 'fails and reports that bolt library is required' do
      expect{eval_and_collect_notices(<<-CODE, node)}.to raise_error(/The 'bolt' library is required to run a command/)
          run_command('echo hello')
      CODE
    end
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that run_command is not available' do
      expect{eval_and_collect_notices(<<-CODE, node)}.to raise_error(/The task operation 'run_command' is not available/)
          run_command('echo hello')
      CODE
    end
  end
end
