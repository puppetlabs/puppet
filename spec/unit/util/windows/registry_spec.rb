#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/windows'

describe Puppet::Util::Windows::Registry, :if => Puppet::Util::Platform.windows? do
  subject do
    class TestRegistry
      include Puppet::Util::Windows::Registry
    end

    TestRegistry.new
  end

  let(:name)   { 'HKEY_LOCAL_MACHINE' }
  let(:path)   { 'Software\Microsoft' }

  context "#root" do
    it "should lookup the root hkey" do
      subject.root(name).should be_instance_of(Win32::Registry::PredefinedKey)
    end

    it "should raise for unknown root keys" do
      expect { subject.root('HKEY_BOGUS') }.to raise_error(Puppet::Error, /Invalid registry key/)
    end
  end

  context "#open" do
    let(:hkey)   { mock 'hklm' }
    let(:subkey) { stub 'subkey' }

    before :each do
      subject.stubs(:root).returns(hkey)
    end

    it "should yield the opened the subkey" do
      hkey.expects(:open).with do |p, _|
        p.should == path
      end.yields(subkey)

      yielded = nil
      subject.open(name, path) {|reg| yielded = reg}
      yielded.should == subkey
    end

    if Puppet::Util::Platform.windows?
      [described_class::KEY64, described_class::KEY32].each do |access|
        it "should open the key for read access 0x#{access.to_s(16)}" do
          mode = described_class::KEY_READ | access
          hkey.expects(:open).with(path, mode)

          subject.open(name, path, mode) {|reg| }
        end
      end
    end

    it "should default to KEY64" do
      hkey.expects(:open).with(path, described_class::KEY_READ | described_class::KEY64)

      subject.open(hkey, path) {|hkey| }
    end

    it "should raise for a path that doesn't exist" do
      hkey.expects(:keyname).returns('HKEY_LOCAL_MACHINE')
      hkey.expects(:open).raises(Win32::Registry::Error.new(2)) # file not found
      expect do
        subject.open(hkey, 'doesnotexist') {|hkey| }
      end.to raise_error(Puppet::Error, /Failed to open registry key 'HKEY_LOCAL_MACHINE\\doesnotexist'/)
    end
  end

  context "#values" do
    let(:key) { stub('uninstall') }

    it "should return each value's name and data" do
      key.expects(:each_value).multiple_yields(
        ['string', 1, 'foo'], ['dword', 4, 0]
      )
      subject.values(key).should == { 'string' => 'foo', 'dword' => 0 }
    end

    it "should return an empty hash if there are no values" do
      key.expects(:each_value)

      subject.values(key).should == {}
    end

    context "when reading non-ASCII values" do
      # registered trademark symbol
      let(:data) do
        str = [0xAE].pack("C")
        str.force_encoding('US-ASCII')
        str
      end

      def expects_registry_value(array)
        key.expects(:each_value).multiple_yields(array)

        subject.values(key).first[1]
      end

      # The win32console gem applies this regex to strip out ANSI escape
      # sequences. If the registered trademark had encoding US-ASCII,
      # the regex would fail with 'invalid byte sequence in US-ASCII'
      def strip_ansi_escapes(value)
        value.sub(/([^\e]*)?\e([\[\(])([0-9\;\=]*)([a-zA-Z@])(.*)/, '\5')
      end

      it "encodes REG_SZ according to the current code page" do
        reg_value = ['string', Win32::Registry::REG_SZ, data]

        value = expects_registry_value(reg_value)

        strip_ansi_escapes(value)
      end

      it "encodes REG_EXPAND_SZ based on the current code page" do
        reg_value = ['expand', Win32::Registry::REG_EXPAND_SZ, "%SYSTEMROOT%\\#{data}"]

        value = expects_registry_value(reg_value)

        strip_ansi_escapes(value)
      end

      it "encodes REG_MULTI_SZ based on the current code page" do
        reg_value = ['multi', Win32::Registry::REG_MULTI_SZ, ["one#{data}", "two#{data}"]]

        value = expects_registry_value(reg_value)

        value.each { |str| strip_ansi_escapes(str) }
      end

      it "passes REG_DWORD through" do
        reg_value = ['dword', Win32::Registry::REG_DWORD, '1']

        value = expects_registry_value(reg_value)

        Integer(value).should == 1
      end
    end
  end
end
