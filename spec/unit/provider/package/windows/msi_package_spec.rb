#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/provider/package/windows/msi_package'

describe Puppet::Provider::Package::Windows::MsiPackage do
  subject { described_class }

  let (:name)        { 'mysql-5.1.58-win-x64' }
  let (:version)     { '5.1.58' }
  let (:source)      { 'E:\mysql-5.1.58-win-x64.msi' }
  let (:productcode) { '{E437FFB6-5C49-4DAC-ABAE-33FF065FE7CC}' }
  let (:packagecode) { '{5A6FD560-763A-4BC1-9E03-B18DFFB7C72C}' }

  def expect_installer
    inst = mock
    inst.expects(:ProductState).returns(5)
    inst.expects(:ProductInfo).with(productcode, 'PackageCode').returns(packagecode)
    subject.expects(:installer).returns(inst)
  end

  context '::installer', :if => Puppet.features.microsoft_windows? do
    it 'should return an instance of the COM interface' do
      subject.installer.should_not be_nil
    end
  end

  context '::from_registry' do
    it 'should return an instance of MsiPackage' do
      subject.expects(:valid?).returns(true)
      expect_installer

      pkg = subject.from_registry(productcode, {'DisplayName' => name, 'DisplayVersion' => version})
      pkg.name.should == name
      pkg.version.should == version
      pkg.productcode.should == productcode
      pkg.packagecode.should == packagecode
    end

    it 'should return nil if it is not a valid MSI' do
      subject.expects(:valid?).returns(false)

      subject.from_registry(productcode, {}).should be_nil
    end
  end

  context '::valid?' do
    let(:values) do { 'DisplayName' => name, 'DisplayVersion' => version, 'WindowsInstaller' => 1 } end

    {
      'DisplayName'      => ['My App', ''],
      'SystemComponent'  => [nil, 1],
      'WindowsInstaller' => [1, nil],
    }.each_pair do |k, arr|
      it "should accept '#{k}' with value '#{arr[0]}'" do
        values[k] = arr[0]
        subject.valid?(productcode, values).should be_true
      end

      it "should reject '#{k}' with value '#{arr[1]}'" do
        values[k] = arr[1]
        subject.valid?(productcode, values).should be_false
      end
    end

    it 'should reject packages whose name is not a productcode' do
     subject.valid?('AddressBook', values).should be_false
   end

   it 'should accept packages whose name is a productcode' do
     subject.valid?(productcode, values).should be_true
   end
  end

  context '#match?' do
    it 'should match package codes case-insensitively' do
      pkg = subject.new(name, version, productcode, packagecode.upcase)

      pkg.match?({:name => packagecode.downcase}).should be_true
    end

    it 'should match product codes case-insensitively' do
      pkg = subject.new(name, version, productcode.upcase, packagecode)

      pkg.match?({:name => productcode.downcase}).should be_true
    end

    it 'should match product name' do
      pkg = subject.new(name, version, productcode, packagecode)

      pkg.match?({:name => name}).should be_true
    end

    it 'should return false otherwise' do
      pkg = subject.new(name, version, productcode, packagecode)

      pkg.match?({:name => 'not going to find it'}).should be_false
    end
  end

  context '#install_command' do
    it 'should install using the source' do
      cmd = subject.install_command({:source => source})

      cmd.should == ['msiexec.exe', '/qn', '/norestart', '/i', source]
    end
  end

  context '#uninstall_command' do
    it 'should uninstall using the productcode' do
      pkg = subject.new(name, version, productcode, packagecode)

      pkg.uninstall_command.should == ['msiexec.exe', '/qn', '/norestart', '/x', productcode]
    end
  end
end
