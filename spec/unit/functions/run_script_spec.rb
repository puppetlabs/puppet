require 'spec_helper'
require 'puppet/pops'
require 'puppet/loaders'
require 'puppet_spec/compiler'

describe 'the run_script function' do
  include PuppetSpec::Compiler
  include PuppetSpec::Files

  let(:executor) { mock('bolt_executor') }
  let(:tasks_enabled) { true }
  let(:env_name) { 'testenv' }
  let(:environments_dir) { Puppet[:environmentpath] }
  let(:env_dir) { File.join(environments_dir, env_name) }
  let(:env) { Puppet::Node::Environment.create(env_name.to_sym, [File.join(populated_env_dir, 'modules')]) }
  let(:node) { Puppet::Node.new("test", :environment => env) }
  let(:env_dir_files) {
    {
      'modules' => {
        'test' => {
          'files' => {
            'uploads' => {
              'hostname.sh' => <<-SH.unindent
                #!/bin/sh
                hostname
               SH
            }
          }
        }
      }
    }
  }

  before(:each) do
    Puppet[:tasks] = tasks_enabled
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

  let(:populated_env_dir) do
    dir_contained_in(environments_dir, env_name => env_dir_files)
    PuppetSpec::Files.record_tmp(env_dir)
    env_dir
  end
  let(:func) { Puppet.lookup(:loaders).puppet_system_loader.load(:function, 'run_script') }

  context 'it calls bolt executor run_script' do
    let(:hostname) { 'test.example.com' }
    let(:hosts) { [hostname] }
    let(:host) { stub(uri: hostname) }
    let(:result) { { value: hostname } }
    let(:full_dir_path) { File.join(env_dir, 'modules', 'test', 'files', 'uploads' ) }
    let(:full_path) { File.join(full_dir_path, 'hostname.sh') }
    before(:each) do
      Puppet.features.stubs(:bolt?).returns(true)
    end

    it 'with fully resolved path of file' do
      executor.expects(:from_uris).with(hosts).returns([host])
      result.expects(:to_h).returns(result)
      executor.expects(:run_script).with([host], full_path, []).returns({ host => result })

      expect(eval_and_collect_notices(<<-CODE, node)).to eql(["ExecutionResult({'#{hostname}' => {value => '#{hostname}'}})"])
        $a = run_script('test/uploads/hostname.sh', '#{hostname}')
        notice $a
      CODE
    end

    it 'with host given as Target' do
      executor.expects(:from_uris).with(hosts).returns([host])
      result.expects(:to_h).returns(result)
      executor.expects(:run_script).with([host], full_path, []).returns({ host => result })

      expect(eval_and_collect_notices(<<-CODE, node)).to eql(["ExecutionResult({'#{hostname}' => {value => '#{hostname}'}})"])
        $a = run_script('test/uploads/hostname.sh', Target('#{hostname}'))
        notice $a
      CODE
    end

    it 'with given arguments as a hash of {arguments => [value]}' do
      executor.expects(:from_uris).with(hosts).returns([host])
      result.expects(:to_h).returns(result)
      executor.expects(:run_script).with([host], full_path, ['hello', 'world']).returns({ host => result })

      expect(eval_and_collect_notices(<<-CODE, node)).to eql(["ExecutionResult({'#{hostname}' => {value => '#{hostname}'}})"])
        $a = run_script('test/uploads/hostname.sh', Target('#{hostname}'), arguments => ['hello', 'world'])
        notice $a
      CODE
    end

    it 'with given arguments as a hash of {arguments => []}' do
      executor.expects(:from_uris).with(hosts).returns([host])
      result.expects(:to_h).returns(result)
      executor.expects(:run_script).with([host], full_path, []).returns({ host => result })

      expect(eval_and_collect_notices(<<-CODE, node)).to eql(["ExecutionResult({'#{hostname}' => {value => '#{hostname}'}})"])
        $a = run_script('test/uploads/hostname.sh', Target('#{hostname}'), arguments => [])
        notice $a
      CODE
    end

    context 'with multiple destinations' do
      let(:hostname2) { 'test.testing.com' }
      let(:hosts) { [hostname, hostname2] }
      let(:host2) { stub(uri: hostname2) }
      let(:result2) { { value: hostname2 } }
      let(:nodes) { [mock(hostname), mock(hostname2)] }

      it 'with propagated multiple hosts and returns multiple results' do
        executor.expects(:from_uris).with(hosts).returns(nodes)
        executor.expects(:run_script).with(nodes, full_path, []).returns({ host => result, host2 => result2 })
        result.expects(:to_h).returns(result)
        result2.expects(:to_h).returns(result2)

        expect(eval_and_collect_notices(<<-CODE, node)).to eql(["ExecutionResult({'#{hostname}' => {value => '#{hostname}'}, '#{hostname2}' => {value => '#{hostname2}'}})"])
          $a = run_script('test/uploads/hostname.sh', '#{hostname}', '#{hostname2}')
          notice $a
        CODE
      end
    end

    it 'without nodes - does not invoke bolt' do
      executor.expects(:from_uris).never
      executor.expects(:run_script).never

      expect(eval_and_collect_notices(<<-CODE, node)).to eql(['ExecutionResult({})'])
        $a = run_script('test/uploads/hostname.sh')
        notice $a
      CODE
    end

    it 'errors when script is not found' do
      executor.expects(:from_uris).never
      executor.expects(:run_script).never

      expect{eval_and_collect_notices(<<-CODE, node)}.to raise_error(/No such file or directory: .*nonesuch\.sh/)
        run_script('test/uploads/nonesuch.sh')
      CODE
    end

    it 'errors when script appoints a directory' do
      executor.expects(:from_uris).never
      executor.expects(:run_script).never

      expect{eval_and_collect_notices(<<-CODE, node)}.to raise_error(/.*\/uploads is not a file/)
        run_script('test/uploads')
      CODE
    end
  end

  context 'without bolt feature present' do
    it 'fails and reports that bolt library is required' do
      Puppet.features.stubs(:bolt?).returns(false)
      expect{eval_and_collect_notices(<<-CODE, node)}.to raise_error(/The 'bolt' library is required to run a script/)
          run_script('test/uploads/nonesuch.sh')
      CODE
    end
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that run_script is not available' do
      expect{eval_and_collect_notices(<<-CODE, node)}.to raise_error(/The task operation 'run_script' is not available/)
          run_script('test/uploads/nonesuch.sh')
      CODE
    end
  end
end
