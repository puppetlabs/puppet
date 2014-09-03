#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/provider/package/windows/package'

describe Puppet::Provider::Package::Windows::Package do
  subject { described_class }

  let(:hklm) { 'HKEY_LOCAL_MACHINE' }
  let(:hkcu) { 'HKEY_CURRENT_USER' }
  let(:path) { 'Software\Microsoft\Windows\CurrentVersion\Uninstall' }
  let(:key)  { mock('key', :name => "#{hklm}\\#{path}\\Google") }
  let(:package)  { mock('package') }

  context '::each' do
    it 'should generate an empty enumeration' do
      subject.expects(:with_key)

      subject.to_a.should be_empty
    end

    it 'should yield each package it finds' do
      subject.expects(:with_key).yields(key, {})

      Puppet::Provider::Package::Windows::MsiPackage.expects(:from_registry).with('Google', {}).returns(package)

      yielded = nil
      subject.each do |pkg|
        yielded = pkg
      end

      yielded.should == package
    end
  end

  context '::with_key', :if => Puppet.features.microsoft_windows? do
    it 'should search HKLM (64 & 32) and HKCU (64 & 32)' do
      seq = sequence('reg')

      subject.expects(:open).with(hklm, path, subject::KEY64 | subject::KEY_READ).in_sequence(seq)
      subject.expects(:open).with(hklm, path, subject::KEY32 | subject::KEY_READ).in_sequence(seq)
      subject.expects(:open).with(hkcu, path, subject::KEY64 | subject::KEY_READ).in_sequence(seq)
      subject.expects(:open).with(hkcu, path, subject::KEY32 | subject::KEY_READ).in_sequence(seq)

      subject.with_key { |key, values| }
    end

    it 'should ignore file not found exceptions' do
      ex = Puppet::Util::Windows::Error.new('Failed to open registry key', Puppet::Util::Windows::Error::ERROR_FILE_NOT_FOUND)

      # make sure we don't stop after the first exception
      subject.expects(:open).times(4).raises(ex)

      keys = []
      subject.with_key { |key, values| keys << key }
      keys.should be_empty
    end

    it 'should raise other types of exceptions' do
      ex = Puppet::Util::Windows::Error.new('Failed to open registry key', Puppet::Util::Windows::Error::ERROR_ACCESS_DENIED)
      subject.expects(:open).raises(ex)

      expect {
        subject.with_key{ |key, values| }
      }.to raise_error(Puppet::Util::Windows::Error, /Access is denied/)
    end
  end

  context '::installer_class' do
    it 'should require the source parameter' do
      expect {
        subject.installer_class({})
      }.to raise_error(Puppet::Error, /The source parameter is required when using the Windows provider./)
    end

    context 'MSI' do
      let (:klass) { Puppet::Provider::Package::Windows::MsiPackage }

      it 'should accept source ending in .msi' do
        subject.installer_class({:source => 'foo.msi'}).should == klass
      end

      it 'should accept quoted source ending in .msi' do
        subject.installer_class({:source => '"foo.msi"'}).should == klass
      end

      it 'should accept source case insensitively' do
        subject.installer_class({:source => '"foo.MSI"'}).should == klass
      end

      it 'should reject source containing msi in the name' do
        expect {
          subject.installer_class({:source => 'mymsi.txt'})
        }.to raise_error(Puppet::Error, /Don't know how to install 'mymsi.txt'/)
      end
    end

    context 'Unknown' do
      it 'should reject packages it does not know about' do
        expect {
          subject.installer_class({:source => 'basram'})
        }.to raise_error(Puppet::Error, /Don't know how to install 'basram'/)
      end
    end
  end

  context '::munge' do
    it 'should shell quote strings with spaces and fix forward slashes' do
      subject.munge('c:/windows/the thing').should == '"c:\windows\the thing"'
    end
    it 'should leave properly formatted paths alone' do
      subject.munge('c:\windows\thething').should == 'c:\windows\thething'
    end
  end

  context '::replace_forward_slashes' do
    it 'should replace forward with back slashes' do
      subject.replace_forward_slashes('c:/windows/thing/stuff').should == 'c:\windows\thing\stuff'
    end
  end

  context '::quote' do
    it 'should shell quote strings with spaces' do
      subject.quote('foo bar').should == '"foo bar"'
    end

    it 'should shell quote strings with spaces and quotes' do
      subject.quote('"foo bar" baz').should == '"\"foo bar\" baz"'
    end

    it 'should not shell quote strings without spaces' do
      subject.quote('"foobar"').should == '"foobar"'
    end
  end

  it 'should implement instance methods' do
    pkg = subject.new('orca', '5.0')

    pkg.name.should == 'orca'
    pkg.version.should == '5.0'
  end
end
