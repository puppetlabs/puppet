#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/provider/package/windows/exe_package'

describe Puppet::Provider::Package::Windows::ExePackage do
  subject { described_class }

  let (:name)        { 'Git version 1.7.11' }
  let (:version)     { '1.7.11' }
  let (:source)      { 'E:\Git-1.7.11.exe' }
  let (:uninstall)   { '"C:\Program Files (x86)\Git\unins000.exe" /SP-' }

  context '::from_registry' do
    it 'should return an instance of ExePackage' do
      subject.expects(:valid?).returns(true)

      pkg = subject.from_registry('', {'DisplayName' => name, 'DisplayVersion' => version, 'UninstallString' => uninstall})
      expect(pkg.name).to eq(name)
      expect(pkg.version).to eq(version)
      expect(pkg.uninstall_string).to eq(uninstall)
    end

    it 'should return nil if it is not a valid executable' do
      subject.expects(:valid?).returns(false)

      expect(subject.from_registry('', {})).to be_nil
    end
  end

  context '::valid?' do
    let(:name)   { 'myproduct' }
    let(:values) do { 'DisplayName' => name, 'UninstallString' => uninstall } end

    {
      'DisplayName'      => ['My App', ''],
      'UninstallString'  => ['E:\uninstall.exe', ''],
      'WindowsInstaller' => [nil, 1],
      'ParentKeyName'    => [nil, 'Uber Product'],
      'Security Update'  => [nil, 'KB890830'],
      'Update Rollup'    => [nil, 'Service Pack 42'],
      'Hotfix'           => [nil, 'QFE 42']
    }.each_pair do |k, arr|
      it "should accept '#{k}' with value '#{arr[0]}'" do
        values[k] = arr[0]
        expect(subject.valid?(name, values)).to be_truthy
      end

      it "should reject '#{k}' with value '#{arr[1]}'" do
        values[k] = arr[1]
        expect(subject.valid?(name, values)).to be_falsey
      end
    end

    it 'should reject packages whose name starts with "KBXXXXXX"' do
      expect(subject.valid?('KB890830', values)).to be_falsey
    end

    it 'should accept packages whose name does not start with "KBXXXXXX"' do
      expect(subject.valid?('My Update (KB890830)', values)).to be_truthy
    end
  end

  context '#match?' do
    let(:pkg) { subject.new(name, version, uninstall) }

    it 'should match product name' do
      expect(pkg.match?({:name => name})).to be_truthy
    end

    it 'should return false otherwise' do
      expect(pkg.match?({:name => 'not going to find it'})).to be_falsey
    end
  end

  context '#install_command' do
    it 'should install using the source' do
      cmd = subject.install_command({:source => source})

      expect(cmd).to eq(['cmd.exe', '/c', 'start', '"puppet-install"', '/w', source])
    end
  end

  context '#uninstall_command' do
    ['C:\uninstall.exe', 'C:\Program Files\uninstall.exe'].each do |exe|
      it "should quote #{exe}" do
        expect(subject.new(name, version, exe).uninstall_command).to eq(
          ['cmd.exe', '/c', 'start', '"puppet-uninstall"', '/w', "\"#{exe}\""]
        )
      end
    end

    ['"C:\Program Files\uninstall.exe"', '"C:\Program Files (x86)\Git\unins000.exe" /SILENT"'].each do |exe|
      it "should not quote #{exe}" do
        expect(subject.new(name, version, exe).uninstall_command).to eq(
          ['cmd.exe', '/c', 'start', '"puppet-uninstall"', '/w', exe]
        )
      end
    end
  end
end
