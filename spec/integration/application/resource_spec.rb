require 'spec_helper'
require 'puppet_spec/files'

describe "puppet resource", unless: Puppet::Util::Platform.jruby? do
  include PuppetSpec::Files

  let(:resource) { Puppet::Application[:resource] }

  describe "when handling file and tidy types" do
    let!(:dir) { dir_containing('testdir', 'testfile' => 'contents') }

    it 'does not raise when generating file resources' do
      resource.command_line.args = ['file', dir, 'ensure=directory', 'recurse=true']

      expect {
        resource.run
      }.to output(/ensure.+=> 'directory'/).to_stdout
    end

    it 'correctly cleans up a given path' do
      resource.command_line.args = ['tidy', dir, 'rmdirs=true', 'recurse=true']

      expect {
        resource.run
      }.to output(/Notice: \/File\[#{dir}\]\/ensure: removed/).to_stdout

      expect(Puppet::FileSystem.exist?(dir)).to be false
    end
  end
end
