#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:package).provider(:windows) do
  let (:name)        { 'mysql-5.1.58-win-x64' }
  let (:source)      { 'E:\mysql-5.1.58-win-x64.msi' }
  let (:resource)    {  Puppet::Type.type(:package).new(:name => name, :provider => :windows, :source => source) }
  let (:provider)    { resource.provider }
  let (:execute_options) do {:failonfail => false, :combine => true} end

  before :each do
    # make sure we never try to execute anything
    provider.expects(:execute).never
  end

  def expect_execute(command, status)
    provider.expects(:execute).with(command, execute_options).returns(Puppet::Util::Execution::ProcessOutput.new('',status))
  end

  describe 'provider features' do
    it { is_expected.to be_installable }
    it { is_expected.to be_uninstallable }
    it { is_expected.to be_install_options }
    it { is_expected.to be_uninstall_options }
    it { is_expected.to be_versionable }
  end

  describe 'on Windows', :if => Puppet.features.microsoft_windows? do
    it 'should be the default provider' do
      expect(Puppet::Type.type(:package).defaultprovider).to eq(subject.class)
    end
  end

  context '::instances' do
    it 'should return an array of provider instances' do
      pkg1 = stub('pkg1')
      pkg2 = stub('pkg2')

      prov1 = stub('prov1', :name => 'pkg1', :version => '1.0.0', :package => pkg1)
      prov2 = stub('prov2', :name => 'pkg2', :version => nil, :package => pkg2)

      Puppet::Provider::Package::Windows::Package.expects(:map).multiple_yields([prov1], [prov2]).returns([prov1, prov2])

      providers = provider.class.instances
      expect(providers.count).to eq(2)
      expect(providers[0].name).to eq('pkg1')
      expect(providers[0].version).to eq('1.0.0')
      expect(providers[0].package).to eq(pkg1)

      expect(providers[1].name).to eq('pkg2')
      expect(providers[1].version).to be_nil
      expect(providers[1].package).to eq(pkg2)
    end

    it 'should return an empty array if none found' do
      Puppet::Provider::Package::Windows::Package.expects(:map).returns([])

      expect(provider.class.instances).to eq([])
    end
  end

  context '#query' do
    it 'should return the hash of the matched packaged' do
      pkg = mock(:name => 'pkg1', :version => nil)
      pkg.expects(:match?).returns(true)
      Puppet::Provider::Package::Windows::Package.expects(:find).yields(pkg)

      expect(provider.query).to eq({ :name => 'pkg1', :ensure => :installed, :provider => :windows })
    end

    it 'should include the version string when present' do
      pkg = mock(:name => 'pkg1', :version => '1.0.0')
      pkg.expects(:match?).returns(true)
      Puppet::Provider::Package::Windows::Package.expects(:find).yields(pkg)

      expect(provider.query).to eq({ :name => 'pkg1', :ensure => '1.0.0', :provider => :windows })
    end

    it 'should return nil if no package was found' do
      Puppet::Provider::Package::Windows::Package.expects(:find)

      expect(provider.query).to be_nil
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
      end.to raise_error do |error|
        expect(error).to be_a(Puppet::Util::Windows::Error)
        expect(error.code).to eq(5) # ERROR_ACCESS_DENIED
      end
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
      end.to raise_error do |error|
        expect(error).to be_a(Puppet::Util::Windows::Error)
        expect(error.code).to eq(5) # ERROR_ACCESS_DENIED
      end
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
      expect(provider.install_options).to be_nil
    end

    it 'should return the options' do
      resource[:install_options] = { 'INSTALLDIR' => 'C:\mysql-here' }

      expect(provider.install_options).to eq(['INSTALLDIR=C:\mysql-here'])
    end

    it 'should only quote if needed' do
      resource[:install_options] = { 'INSTALLDIR' => 'C:\mysql here' }

      expect(provider.install_options).to eq(['INSTALLDIR="C:\mysql here"'])
    end

    it 'should escape embedded quotes in install_options values with spaces' do
      resource[:install_options] = { 'INSTALLDIR' => 'C:\mysql "here"' }

      expect(provider.install_options).to eq(['INSTALLDIR="C:\mysql \"here\""'])
    end
  end

  context '#uninstall_options' do
    it 'should return nil by default' do
      expect(provider.uninstall_options).to be_nil
    end

    it 'should return the options' do
      resource[:uninstall_options] = { 'INSTALLDIR' => 'C:\mysql-here' }

      expect(provider.uninstall_options).to eq(['INSTALLDIR=C:\mysql-here'])
    end
  end

  context '#join_options' do
    it 'should return nil if there are no options' do
      expect(provider.join_options(nil)).to be_nil
    end

    it 'should sort hash keys' do
      expect(provider.join_options([{'b' => '2', 'a' => '1', 'c' => '3'}])).to eq(['a=1', 'b=2', 'c=3'])
    end

    it 'should return strings and hashes' do
      expect(provider.join_options([{'a' => '1'}, 'b'])).to eq(['a=1', 'b'])
    end
  end
end
