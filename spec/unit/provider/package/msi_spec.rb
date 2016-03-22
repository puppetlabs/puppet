#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:package).provider(:msi) do
  let (:name)        { 'mysql-5.1.58-win-x64' }
  let (:source)      { 'E:\mysql-5.1.58-win-x64.msi' }
  let (:productcode) { '{E437FFB6-5C49-4DAC-ABAE-33FF065FE7CC}' }
  let (:packagecode) { '{5A6FD560-763A-4BC1-9E03-B18DFFB7C72C}' }
  let (:resource)    {  Puppet::Type.type(:package).new(:name => name, :provider => :msi, :source => source) }
  let (:provider)    { resource.provider }
  let (:execute_options) do {:failonfail => false, :combine => true} end

  def installer(productcodes)
    installer = mock
    installer.expects(:UILevel=).with(2)

    installer.stubs(:ProductState).returns(5)
    installer.stubs(:Products).returns(productcodes)
    productcodes.each do |guid|
      installer.stubs(:ProductInfo).with(guid, 'ProductName').returns("name-#{guid}")
      installer.stubs(:ProductInfo).with(guid, 'PackageCode').returns("package-#{guid}")
    end

    MsiPackage.stubs(:installer).returns(installer)
  end

  def expect_execute(command, status)
    provider.expects(:execute).with(command, execute_options).returns(Puppet::Util::Execution::ProcessOutput.new('',status))
  end

  describe 'provider features' do
    it { should be_installable }
    it { should be_uninstallable }
    it { should be_install_options }
    it { should be_uninstall_options }
  end

  describe 'on Windows', :as_platform => :windows do
    after :each do
      Puppet::Type.type(:package).defaultprovider = nil
    end

    it 'should not be the default provider' do
      # provider.expects(:execute).never
      Puppet::Type.type(:package).defaultprovider.should_not == subject.class
    end
  end

  context '::instances' do
    it 'should return an empty array' do
      described_class.instances.should == []
    end
  end

  context '#initialize' do
    it 'should issue a deprecation warning' do
      Puppet.expects(:deprecation_warning).with("The `:msi` package provider is deprecated, use the `:windows` provider instead.")

      Puppet::Type.type(:package).new(:name => name, :provider => :msi, :source => source)
    end
  end

  context '#query' do
    let (:package) do {
        :name        => name,
        :ensure      => :installed,
        :provider    => :msi,
        :productcode => productcode,
        :packagecode => packagecode.upcase
      }
    end

    before :each do
      MsiPackage.stubs(:each).yields(package)
    end

    it 'should match package codes case-insensitively' do
      resource[:name] = packagecode.downcase

      provider.query.should == package
    end

    it 'should match product name' do
      resource[:name] = name

      provider.query.should == package
    end

    it 'should return nil if none found' do
      resource[:name] = 'not going to find it'

      provider.query.should be_nil
    end
  end

  context '#install' do
    let (:command) { "msiexec.exe /qn /norestart /i #{source}" }

    it 'should require the source parameter' do
      resource = Puppet::Type.type(:package).new(:name => name, :provider => :msi)

      expect do
        resource.provider.install
      end.to raise_error(Puppet::Error, /The source parameter is required when using the MSI provider/)
    end

    it 'should install using the source and install_options' do
      resource[:install_options] = { 'INSTALLDIR' => 'C:\mysql-5.1' }
      expect_execute("#{command} INSTALLDIR=C:\\mysql-5.1", 0)

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

    let (:command) { "msiexec.exe /qn /norestart /x #{productcode}" }

    before :each do
      resource[:ensure] = :absent
      provider.set(:productcode => productcode)
    end

    it 'should require the productcode' do
      provider.set(:productcode => nil)
      expect do
        provider.uninstall
      end.to raise_error(Puppet::Error, /The productcode property is missing./)
    end

    it 'should uninstall using the productcode' do
      expect_execute(command, 0)

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
      end.to raise_error(Puppet::Error, /The source parameter cannot be empty when using the MSI provider/)
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
end
