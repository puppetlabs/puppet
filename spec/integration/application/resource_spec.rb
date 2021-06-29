require 'spec_helper'
require 'puppet_spec/files'

describe "puppet resource", unless: Puppet::Util::Platform.jruby? do
  include PuppetSpec::Files

  let(:resource) { Puppet::Application[:resource] }

  context 'when given an invalid environment' do
    before { Puppet[:environment] = 'badenv' }

    it 'falls back to the default environment' do
      Puppet[:log_level] = 'debug'

      expect {
        resource.run
      }.to exit_with(1)
       .and output(/Debug: Specified environment 'badenv' does not exist on the filesystem, defaulting to 'production'/).to_stdout
       .and output(/Error: Could not run: You must specify the type to display/).to_stderr
    end

    it 'lists resources' do
      resource.command_line.args = ['file', Puppet[:confdir]]

      expect {
        resource.run
      }.to output(/file { '#{Puppet[:confdir]}':/).to_stdout
    end

    it 'lists types from the default environment' do
      modulepath = File.join(Puppet[:codedir], 'modules', 'test', 'lib', 'puppet', 'type')
      FileUtils.mkdir_p(modulepath)
      File.write(File.join(modulepath, 'test.rb'), 'Puppet::Type.newtype(:test)')
      resource.command_line.args = ['--types']

      expect {
        resource.run
      }.to exit_with(0).and output(/test/).to_stdout
    end
  end


  context 'when handling file and tidy types' do
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
