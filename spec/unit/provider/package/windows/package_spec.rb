require 'spec_helper'
require 'puppet/provider/package/windows/package'

describe Puppet::Provider::Package::Windows::Package do
  let(:hklm) { 'HKEY_LOCAL_MACHINE' }
  let(:hkcu) { 'HKEY_CURRENT_USER' }
  let(:path) { 'Software\Microsoft\Windows\CurrentVersion\Uninstall' }
  let(:key)  { double('key', :name => "#{hklm}\\#{path}\\Google") }
  let(:package)  { double('package') }

  context '::each' do
    it 'should generate an empty enumeration' do
      expect(described_class).to receive(:with_key)

      expect(described_class.to_a).to be_empty
    end

    it 'should yield each package it finds' do
      expect(described_class).to receive(:with_key).and_yield(key, {})

      expect(Puppet::Provider::Package::Windows::MsiPackage).to receive(:from_registry).with('Google', {}).and_return(package)

      yielded = nil
      described_class.each do |pkg|
        yielded = pkg
      end

      expect(yielded).to eq(package)
    end
  end

  context '::with_key', :if => Puppet::Util::Platform.windows? do
    it 'should search HKLM (64 & 32) and HKCU (64 & 32)' do
      expect(described_class).to receive(:open).with(hklm, path, described_class::KEY64 | described_class::KEY_READ).ordered
      expect(described_class).to receive(:open).with(hklm, path, described_class::KEY32 | described_class::KEY_READ).ordered
      expect(described_class).to receive(:open).with(hkcu, path, described_class::KEY64 | described_class::KEY_READ).ordered
      expect(described_class).to receive(:open).with(hkcu, path, described_class::KEY32 | described_class::KEY_READ).ordered

      described_class.with_key { |key, values| }
    end

    it 'should ignore file not found exceptions' do
      ex = Puppet::Util::Windows::Error.new('Failed to open registry key', Puppet::Util::Windows::Error::ERROR_FILE_NOT_FOUND)

      # make sure we don't stop after the first exception
      expect(described_class).to receive(:open).exactly(4).times().and_raise(ex)

      keys = []
      described_class.with_key { |key, values| keys << key }
      expect(keys).to be_empty
    end

    it 'should raise other types of exceptions' do
      ex = Puppet::Util::Windows::Error.new('Failed to open registry key', Puppet::Util::Windows::Error::ERROR_ACCESS_DENIED)
      expect(described_class).to receive(:open).and_raise(ex)

      expect {
        described_class.with_key{ |key, values| }
      }.to raise_error do |error|
        expect(error).to be_a(Puppet::Util::Windows::Error)
        expect(error.code).to eq(5) # ERROR_ACCESS_DENIED
      end
    end
  end

  context '::installer_class' do
    it 'should require the source parameter' do
      expect {
        described_class.installer_class({})
      }.to raise_error(Puppet::Error, /The source parameter is required when using the Windows provider./)
    end

    context 'MSI' do
      let (:klass) { Puppet::Provider::Package::Windows::MsiPackage }

      it 'should accept source ending in .msi' do
        expect(described_class.installer_class({:source => 'foo.msi'})).to eq(klass)
      end

      it 'should accept quoted source ending in .msi' do
        expect(described_class.installer_class({:source => '"foo.msi"'})).to eq(klass)
      end

      it 'should accept source case insensitively' do
        expect(described_class.installer_class({:source => '"foo.MSI"'})).to eq(klass)
      end

      it 'should reject source containing msi in the name' do
        expect {
          described_class.installer_class({:source => 'mymsi.txt'})
        }.to raise_error(Puppet::Error, /Don't know how to install 'mymsi.txt'/)
      end
    end

    context 'Unknown' do
      it 'should reject packages it does not know about' do
        expect {
          described_class.installer_class({:source => 'basram'})
        }.to raise_error(Puppet::Error, /Don't know how to install 'basram'/)
      end
    end
  end

  context '::munge' do
    it 'should shell quote strings with spaces and fix forward slashes' do
      expect(described_class.munge('c:/windows/the thing')).to eq('"c:\windows\the thing"')
    end
    it 'should leave properly formatted paths alone' do
      expect(described_class.munge('c:\windows\thething')).to eq('c:\windows\thething')
    end
  end

  context '::replace_forward_slashes' do
    it 'should replace forward with back slashes' do
      expect(described_class.replace_forward_slashes('c:/windows/thing/stuff')).to eq('c:\windows\thing\stuff')
    end
  end

  context '::quote' do
    it 'should shell quote strings with spaces' do
      expect(described_class.quote('foo bar')).to eq('"foo bar"')
    end

    it 'should shell quote strings with spaces and quotes' do
      expect(described_class.quote('"foo bar" baz')).to eq('"\"foo bar\" baz"')
    end

    it 'should not shell quote strings without spaces' do
      expect(described_class.quote('"foobar"')).to eq('"foobar"')
    end
  end

  context '::get_display_name' do
    it 'should return nil if values is nil' do
      expect(described_class.get_display_name(nil)).to be_nil
    end

    it 'should return empty if values is empty' do
      reg_values =  {}
      expect(described_class.get_display_name(reg_values)).to eq('')
    end

    it 'should return DisplayName when available' do
      reg_values =  { 'DisplayName' => 'Google' }
      expect(described_class.get_display_name(reg_values)).to eq('Google')
    end

    it 'should return DisplayName when available, even when QuietDisplayName is also available' do
      reg_values =  { 'DisplayName' => 'Google', 'QuietDisplayName' => 'Google Quiet' }
      expect(described_class.get_display_name(reg_values)).to eq('Google')
    end

    it 'should return QuietDisplayName when available if DisplayName is empty' do
      reg_values =  { 'DisplayName' => '', 'QuietDisplayName' =>'Google Quiet' }
      expect(described_class.get_display_name(reg_values)).to eq('Google Quiet')
    end

    it 'should return QuietDisplayName when DisplayName is not available' do
      reg_values =  { 'QuietDisplayName' =>'Google Quiet' }
      expect(described_class.get_display_name(reg_values)).to eq('Google Quiet')
    end

    it 'should return empty when DisplayName is empty and QuietDisplay name is not available' do
      reg_values =  { 'DisplayName' => '' }
      expect(described_class.get_display_name(reg_values)).to eq('')
    end

    it 'should return empty when DisplayName is empty and QuietDisplay name is empty' do
      reg_values =  { 'DisplayName' => '', 'QuietDisplayName' =>'' }
      expect(described_class.get_display_name(reg_values)).to eq('')
    end
  end

  it 'should implement instance methods' do
    pkg = described_class.new('orca', '5.0')

    expect(pkg.name).to eq('orca')
    expect(pkg.version).to eq('5.0')
  end
end
