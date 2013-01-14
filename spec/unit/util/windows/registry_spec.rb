#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/windows'
require 'puppet/util/windows/registry'

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

    [described_class::KEY64, described_class::KEY32].each do |access|
      it "should open the key for read access 0x#{access.to_s(16)}" do
        mode = described_class::KEY_READ | access
        hkey.expects(:open).with(path, mode)

        subject.open(name, path, mode) {|reg| }
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
  end
end
