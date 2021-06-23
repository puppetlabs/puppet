require 'spec_helper'
require 'puppet/provider/package/windows/exe_package'
require 'puppet/provider/package/windows'

describe Puppet::Provider::Package::Windows::ExePackage do
  let (:name)        { 'Git version 1.7.11' }
  let (:version)     { '1.7.11' }
  let (:source)      { 'E:\Git-1.7.11.exe' }
  let (:uninstall)   { '"C:\Program Files (x86)\Git\unins000.exe" /SP-' }

  context '::from_registry' do
    it 'should return an instance of ExePackage' do
      expect(described_class).to receive(:valid?).and_return(true)

      pkg = described_class.from_registry('', {'DisplayName' => name, 'DisplayVersion' => version, 'UninstallString' => uninstall})
      expect(pkg.name).to eq(name)
      expect(pkg.version).to eq(version)
      expect(pkg.uninstall_string).to eq(uninstall)
    end

    it 'should return nil if it is not a valid executable' do
      expect(described_class).to receive(:valid?).and_return(false)

      expect(described_class.from_registry('', {})).to be_nil
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
        expect(described_class.valid?(name, values)).to be_truthy
      end

      it "should reject '#{k}' with value '#{arr[1]}'" do
        values[k] = arr[1]
        expect(described_class.valid?(name, values)).to be_falsey
      end
    end

    it 'should reject packages whose name starts with "KBXXXXXX"' do
      expect(described_class.valid?('KB890830', values)).to be_falsey
    end

    it 'should accept packages whose name does not start with "KBXXXXXX"' do
      expect(described_class.valid?('My Update (KB890830)', values)).to be_truthy
    end
  end

  context '#match?' do
    let(:pkg) { described_class.new(name, version, uninstall) }

    it 'should match product name' do
      expect(pkg.match?({:name => name})).to be_truthy
    end

    it 'should return false otherwise' do
      expect(pkg.match?({:name => 'not going to find it'})).to be_falsey
    end
  end

  context '#install_command' do
    it 'should install using the source' do
      allow(Puppet::FileSystem).to receive(:exist?).with(source).and_return(true)
      cmd = described_class.install_command({:source => source})

      expect(cmd).to eq(source)
    end

    it 'should raise error when URI is invalid' do
      web_source = 'https://www.t e s t.test/test.exe'

      expect do
        described_class.install_command({:source => web_source, :name => name})
      end.to raise_error(Puppet::Error, /Error when installing #{name}:/)
    end

    it 'should download package from source file before installing', if: Puppet::Util::Platform.windows? do
      web_source = 'https://www.test.test/test.exe'
      stub_request(:get, web_source).to_return(status: 200, body: 'package binaries')
      cmd = described_class.install_command({:source => web_source})
      expect(File.read(cmd)).to eq('package binaries')
    end
  end

  context '#uninstall_command' do
    ['C:\uninstall.exe', 'C:\Program Files\uninstall.exe'].each do |exe|
      it "should quote #{exe}" do
        expect(described_class.new(name, version, exe).uninstall_command).to eq(
          "\"#{exe}\""
        )
      end
    end

    ['"C:\Program Files\uninstall.exe"', '"C:\Program Files (x86)\Git\unins000.exe" /SILENT"'].each do |exe|
      it "should not quote #{exe}" do
        expect(described_class.new(name, version, exe).uninstall_command).to eq(
          exe
        )
      end
    end
  end
end
