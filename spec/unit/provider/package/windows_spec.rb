#! /usr/bin/env ruby -S rspec
require 'spec_helper'

describe Puppet::Type.type(:package).provider(:windows) do
  let (:name)        { 'mysql-5.1.58-win-x64' }
  let (:source)      { 'E:\mysql-5.1.58-win-x64.msi' }
  let (:resource)    {  Puppet::Type.type(:package).new(:name => name, :provider => :windows, :source => source) }
  let (:provider)    { resource.provider }
  let (:execute_options) do {:combine => true} end

  before :each do
    # make sure we never try to execute anything
    provider.expects(:execute).never
  end

  def expect_execute(command, status)
    provider.expects(:execute).with(command, execute_options)
    provider.expects(:exit_status).returns(status)
  end

  describe 'provider features' do
    it { should be_installable }
    it { should be_uninstallable }
    it { should be_install_options }
    it { should be_uninstall_options }
  end

  describe 'on Windows', :if => Puppet.features.microsoft_windows? do
    it 'should be the default provider' do
      Puppet::Type.type(:package).defaultprovider.should == subject.class
    end
  end

  context '::instances' do
    it 'should return an array of provider instances' do
      pkg1 = stub('pkg1')
      pkg2 = stub('pkg2')
      prov1 = stub(:name => 'pkg1', :package => pkg1)
      prov2 = stub(:name => 'pkg2', :package => pkg2)
      Puppet::Provider::Package::Windows::Package.expects(:map).multiple_yields(prov1, prov2).returns([prov1, prov2])

      providers = provider.class.instances
      providers.count.should == 2
      providers[0].name.should == 'pkg1'
      providers[0].package.should == pkg1

      providers[1].name.should == 'pkg2'
      providers[1].package.should == pkg2
    end

    it 'should return an empty array if none found' do
      Puppet::Provider::Package::Windows::Package.expects(:map).returns([])

      provider.class.instances.should == []
    end
  end

  context '#query' do
    it 'should return the hash of the matched packaged' do
      pkg = mock(:name => 'pkg1')
      pkg.expects(:match?).returns(true)
      Puppet::Provider::Package::Windows::Package.expects(:find).yields(pkg)

      provider.query.should == { :name => 'pkg1', :ensure => :installed, :provider => :windows }
    end

    it 'should return nil if no package was found' do
      Puppet::Provider::Package::Windows::Package.expects(:find)

      provider.query.should be_nil
    end
  end

  context '#install' do
    let(:command) { 'blarg.exe /S' }
    let(:klass) { mock('installer', :install_command => ['blarg.exe', '/S'] ) }

    before :each do
      Puppet::Provider::Package::Windows::Package.expects(:installer_class).returns(klass)
    end

    it 'should join the install command and options' do
      resource[:install_options] = { 'INSTALLDIR' => 'C:\mysql-5.1' }

      expect_execute("#{command} INSTALLDIR=C:\\mysql-5.1", 0)

      provider.install
    end

    it 'should compact nil install options' do
      expect_execute(command, 0)

      provider.install
    end

    it 'should not warn if the package install succeeds' do
      expect_execute(command, 0)
      provider.expects(:warning).never

      provider.install
    end

    it 'should warn if the package requests a reboot' do
      expect_execute(command, 194)
      provider.expects(:warning).with('The package requested a reboot to finish the operation.')

      provider.install
    end

    it 'should warn if reboot initiated' do
      expect_execute(command, 1641)
      provider.expects(:warning).with('The package installed successfully and the system is rebooting now.')

      provider.install
    end

    it 'should warn if reboot required' do
      expect_execute(command, 3010)
      provider.expects(:warning).with('The package installed successfully, but the system must be rebooted.')

      provider.install
    end

    it 'should fail otherwise', :if => Puppet.features.microsoft_windows? do
      expect_execute(command, 5)

      expect do
        provider.install
      end.to raise_error(Puppet::Util::Windows::Error, /Access is denied/)
    end
  end

  context '#uninstall' do
    let(:command) { 'unblarg.exe /Q' }
    let(:package) { mock('package', :uninstall_command => ['unblarg.exe', '/Q'] ) }

    before :each do
      resource[:ensure] = :absent
      provider.package = package
    end

    it 'should join the uninstall command and options' do
      resource[:uninstall_options] = { 'INSTALLDIR' => 'C:\mysql-5.1' }
      expect_execute("#{command} INSTALLDIR=C:\\mysql-5.1", 0)

      provider.uninstall
    end

    it 'should compact nil install options' do
      expect_execute(command, 0)

      provider.uninstall
    end

    it 'should not warn if the package install succeeds' do
      expect_execute(command, 0)
      provider.expects(:warning).never

      provider.uninstall
    end

    it 'should warn if the package requests a reboot' do
      expect_execute(command, 194)
      provider.expects(:warning).with('The package requested a reboot to finish the operation.')

      provider.uninstall
    end

    it 'should warn if reboot initiated' do
      expect_execute(command, 1641)
      provider.expects(:warning).with('The package uninstalled successfully and the system is rebooting now.')

      provider.uninstall
    end

    it 'should warn if reboot required' do
      expect_execute(command, 3010)
      provider.expects(:warning).with('The package uninstalled successfully, but the system must be rebooted.')

      provider.uninstall
    end

    it 'should fail otherwise', :if => Puppet.features.microsoft_windows? do
      expect_execute(command, 5)

      expect do
        provider.uninstall
      end.to raise_error(Puppet::Util::Windows::Error, /Failed to uninstall.*Access is denied/)
    end
  end

  context '#validate_source' do
    it 'should fail if the source parameter is empty' do
      expect do
        resource[:source] = ''
      end.to raise_error(Puppet::Error, /The source parameter cannot be empty when using the Windows provider/)
    end

    it 'should accept a source' do
      resource[:source] = source
    end
  end

  context '#install_options' do
    it 'should return nil by default' do
      provider.install_options.should be_nil
    end

    it 'should return the options' do
      resource[:install_options] = { 'INSTALLDIR' => 'C:\mysql-here' }

      provider.install_options.should == ['INSTALLDIR=C:\mysql-here']
    end

    it 'should only quote if needed' do
      resource[:install_options] = { 'INSTALLDIR' => 'C:\mysql here' }

      provider.install_options.should == ['INSTALLDIR="C:\mysql here"']
    end

    it 'should escape embedded quotes in install_options values with spaces' do
      resource[:install_options] = { 'INSTALLDIR' => 'C:\mysql "here"' }

      provider.install_options.should == ['INSTALLDIR="C:\mysql \"here\""']
    end
  end

  context '#uninstall_options' do
    it 'should return nil by default' do
      provider.uninstall_options.should be_nil
    end

    it 'should return the options' do
      resource[:uninstall_options] = { 'INSTALLDIR' => 'C:\mysql-here' }

      provider.uninstall_options.should == ['INSTALLDIR=C:\mysql-here']
    end
  end

  context '#join_options' do
    it 'should return nil if there are no options' do
      provider.join_options(nil).should be_nil
    end

    it 'should sort hash keys' do
      provider.join_options([{'b' => '2', 'a' => '1', 'c' => '3'}]).should == ['a=1 b=2 c=3']
    end

    it 'should return strings and hashes' do
      provider.join_options([{'a' => '1'}, 'b']).should == ['a=1', 'b']
    end
  end
end
