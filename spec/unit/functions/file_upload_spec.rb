require 'spec_helper'
require 'puppet/pops'
require 'puppet/loaders'
require 'puppet_spec/compiler'

describe 'the file_upload function' do
  include PuppetSpec::Compiler
  include PuppetSpec::Files

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
              'index.html' => <<-HTML.unindent
                <html>
                  <body>Hello World</body>
                </html>
                HTML
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

  after(:each) do
    Puppet::Pops::Loaders.clear
    Puppet::pop_context()
  end

  let(:populated_env_dir) do
    dir_contained_in(environments_dir, env_name => env_dir_files)
    PuppetSpec::Files.record_tmp(env_dir)
    env_dir
  end
  let(:func) { Puppet.lookup(:loaders).puppet_system_loader.load(:function, 'file_upload') }

  context 'it calls bolt executor file_upload' do
    let(:hostname) { 'test.example.com' }
    let(:hosts) { [hostname] }
    let(:host) { stub(uri: hostname) }
    let(:message) { 'uploaded' }
    let(:result) { stub(output_string: message, success?: true) }
    let(:full_dir_path) { File.join(env_dir, 'modules', 'test', 'files', 'uploads' ) }
    let(:full_path) { File.join(full_dir_path, 'index.html') }
    let(:destination) { '/var/www/html' }
    before(:each) do
      Puppet.features.stubs(:bolt?).returns(true)
      module ::Bolt; end
      class ::Bolt::Executor; end
    end

    it 'with fully resolved path of file and destination' do
      executor = mock('executor')
      Bolt::Executor.expects(:from_uris).with(hosts).returns(executor)
      executor.expects(:file_upload).with(full_path, destination).returns({ host => result })

      expect(eval_and_collect_notices(<<-CODE, node)).to eql(["[#{message}]"])
        $a = file_upload('test/uploads/index.html', '#{destination}', '#{hostname}')
        notice $a
      CODE
    end

    it 'with fully resolved path of directory and destination' do
      executor = mock('executor')
      Bolt::Executor.expects(:from_uris).with(hosts).returns(executor)
      executor.expects(:file_upload).with(full_dir_path, destination).returns({ host => result })

      expect(eval_and_collect_notices(<<-CODE, node)).to eql(["[#{message}]"])
        $a = file_upload('test/uploads', '#{destination}', '#{hostname}')
        notice $a
      CODE
    end

    context 'with multiple destinations' do
      let(:hostname2) { 'test.testing.com' }
      let(:hosts) { [hostname, hostname2] }
      let(:host2) { stub(uri: hostname2) }
      let(:message2) { 'received' }
      let(:result2) { stub(output_string: message2, success?: true) }

      it 'with propagates multiple hosts and returns multiple results' do
        executor = mock('executor')
        Bolt::Executor.expects(:from_uris).with(hosts).returns(executor)
        executor.expects(:file_upload).with(full_path, destination).returns({ host => result, host2 => result2 })

        expect(eval_and_collect_notices(<<-CODE, node)).to eql(["[#{message}, #{message2}]"])
          $a = file_upload('test/uploads/index.html', '#{destination}', '#{hostname}', '#{hostname2}')
          notice $a
        CODE
      end
    end

    it 'without nodes - does not invoke bolt' do
      executor = mock('executor')
      Bolt::Executor.expects(:from_uris).never
      executor.expects(:file_upload).never

      expect(eval_and_collect_notices(<<-CODE, node)).to eql(['[]'])
        $a = file_upload('test/uploads/index.html', '#{destination}')
        notice $a
      CODE
    end

    it 'errors when file is not found' do
      executor = mock('executor')
      Bolt::Executor.expects(:from_uris).never
      executor.expects(:file_upload).never

      expect{eval_and_collect_notices(<<-CODE, node)}.to raise_error(/No such file or directory: .*nonesuch\.html/)
        file_upload('test/uploads/nonesuch.html', '/some/place')
      CODE
    end
  end

  context 'without bolt feature present' do
    it 'fails and reports that bolt library is required' do
      expect{eval_and_collect_notices(<<-CODE, node)}.to raise_error(/The 'bolt' library is required to do file uploads/)
          file_upload('test/uploads/nonesuch.html', '/some/place')
      CODE
    end
  end

  context 'without tasks enabled' do
    let(:tasks_enabled) { false }

    it 'fails and reports that file_upload is not available' do
      expect{eval_and_collect_notices(<<-CODE, node)}.to raise_error(/The task operation 'file_upload' is not available/)
          file_upload('test/uploads/nonesuch.html', '/some/place')
      CODE
    end
  end
end
