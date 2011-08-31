require 'spec_helper'

describe 'Puppet::Provider::Package::Msi' do
  include PuppetSpec::Files

  before :each do
    Puppet::Type.type(:package).stubs(:defaultprovider).returns(Puppet::Type.type(:package).provider(:msi))
    Puppet[:vardir] = tmpdir('msi')
    @state_dir = File.join(Puppet[:vardir], 'db', 'package', 'msi')
  end

  describe 'when installing' do
    it 'should create a state file' do
      resource = Puppet::Type.type(:package).new(
        :name   => 'mysql-5.1.58-winx64',
        :source => 'E:\mysql-5.1.58-winx64.msi'
      )
      resource.provider.stubs(:execute)
      resource.provider.install

      File.should be_exists File.join(@state_dir, 'mysql-5.1.58-winx64.yml')
    end

    it 'should use the install_options as parameter/value pairs' do
      resource = Puppet::Type.type(:package).new(
        :name            => 'mysql-5.1.58-winx64',
        :source          => 'E:\mysql-5.1.58-winx64.msi',
        :install_options => { 'INSTALLDIR' => 'C:\mysql-here' }
      )

      resource.provider.expects(:execute).with('msiexec.exe /qn /norestart /i E:\mysql-5.1.58-winx64.msi INSTALLDIR=C:\mysql-here')
      resource.provider.install
    end

    it 'should only quote the value when an install_options value has a space in it' do
      resource = Puppet::Type.type(:package).new(
        :name            => 'mysql-5.1.58-winx64',
        :source          => 'E:\mysql-5.1.58-winx64.msi',
        :install_options => { 'INSTALLDIR' => 'C:\mysql here' }
      )

      resource.provider.expects(:execute).with('msiexec.exe /qn /norestart /i E:\mysql-5.1.58-winx64.msi INSTALLDIR="C:\mysql here"')
      resource.provider.install
    end

    it 'should escape embedded quotes in install_options values with spaces' do
      resource = Puppet::Type.type(:package).new(
        :name            => 'mysql-5.1.58-winx64',
        :source          => 'E:\mysql-5.1.58-winx64.msi',
        :install_options => { 'INSTALLDIR' => 'C:\mysql "here"' }
      )

      resource.provider.expects(:execute).with('msiexec.exe /qn /norestart /i E:\mysql-5.1.58-winx64.msi INSTALLDIR="C:\mysql \"here\""')
      resource.provider.install
    end

    it 'should not create a state file, if the installation fails' do
      resource = Puppet::Type.type(:package).new(
        :name   => 'mysql-5.1.58-winx64',
        :source => 'E:\mysql-5.1.58-winx64.msi'
      )
      resource.provider.stubs(:execute).raises(Puppet::ExecutionFailure.new("Execution of 'msiexec.exe' returned 128: Blargle"))
      expect { resource.provider.install }.to raise_error(Puppet::ExecutionFailure, /msiexec\.exe/)

      File.should_not be_exists File.join(@state_dir, 'mysql-5.1.58-winx64.yml')
    end

    it 'should fail if the source parameter is not set' do
      expect do
        resource = Puppet::Type.type(:package).new(
          :name => 'mysql-5.1.58-winx64'
        )
      end.to raise_error(Puppet::Error, /The source parameter is required when using the MSI provider/)
    end

    it 'should fail if the source parameter is empty' do
      expect do
        resource = Puppet::Type.type(:package).new(
          :name   => 'mysql-5.1.58-winx64',
          :source => ''
        )
      end.to raise_error(Puppet::Error, /The source parameter cannot be empty when using the MSI provider/)
    end
  end

  describe 'when uninstalling' do
    before :each do
      FileUtils.mkdir_p(@state_dir)
      File.open(File.join(@state_dir, 'mysql-5.1.58-winx64.yml'), 'w') {|f| f.puts 'Hello'}
    end

    it 'should remove the state file' do
      resource = Puppet::Type.type(:package).new(
        :name   => 'mysql-5.1.58-winx64',
        :source => 'E:\mysql-5.1.58-winx64.msi'
      )
      resource.provider.stubs(:msiexec)
      resource.provider.uninstall

      File.should_not be_exists File.join(Puppet[:vardir], 'db', 'package', 'msi', 'mysql-5.1.58-winx64.yml')
    end

    it 'should leave the state file if uninstalling fails' do
      resource = Puppet::Type.type(:package).new(
        :name   => 'mysql-5.1.58-winx64',
        :source => 'E:\mysql-5.1.58-winx64.msi'
      )
      resource.provider.stubs(:msiexec).raises(Puppet::ExecutionFailure.new("Execution of 'msiexec.exe' returned 128: Blargle"))
      expect { resource.provider.uninstall }.to raise_error(Puppet::ExecutionFailure, /msiexec\.exe/)

      File.should be_exists File.join(@state_dir, 'mysql-5.1.58-winx64.yml')
    end

    it 'should fail if the source parameter is not set' do
      expect do
        resource = Puppet::Type.type(:package).new(
          :name => 'mysql-5.1.58-winx64'
        )
      end.to raise_error(Puppet::Error, /The source parameter is required when using the MSI provider/)
    end

    it 'should fail if the source parameter is empty' do
      expect do
        resource = Puppet::Type.type(:package).new(
          :name   => 'mysql-5.1.58-winx64',
          :source => ''
        )
      end.to raise_error(Puppet::Error, /The source parameter cannot be empty when using the MSI provider/)
    end
  end

  describe 'when enumerating instances' do
    it 'should consider the base of the state file name to be the name of the package' do
      FileUtils.mkdir_p(@state_dir)
      package_names = ['GoogleChromeStandaloneEnterprise', 'mysql-5.1.58-winx64', 'postgresql-8.3']

      package_names.each do |state_file|
        File.open(File.join(@state_dir, "#{state_file}.yml"), 'w') {|f| f.puts 'Hello'}
      end

      installed_package_names = Puppet::Type.type(:package).provider(:msi).instances.collect {|p| p.name}

      installed_package_names.should =~ package_names
    end
  end

  it 'should consider the package installed if the state file is present' do
    FileUtils.mkdir_p(@state_dir)
    File.open(File.join(@state_dir, 'mysql-5.1.58-winx64.yml'), 'w') {|f| f.puts 'Hello'}

    resource = Puppet::Type.type(:package).new(
      :name   => 'mysql-5.1.58-winx64',
      :source => 'E:\mysql-5.1.58-winx64.msi'
    )

    resource.provider.query.should == {
      :name   => 'mysql-5.1.58-winx64',
      :ensure => :installed
    }
  end

  it 'should consider the package absent if the state file is missing' do
    resource = Puppet::Type.type(:package).new(
      :name   => 'mysql-5.1.58-winx64',
      :source => 'E:\mysql-5.1.58-winx64.msi'
    )

    resource.provider.query.should be_nil
  end
end
