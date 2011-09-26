#!/usr/bin/env rspec

require 'spec_helper'
if Puppet.features.microsoft_windows?
  require 'puppet/util/windows'
  class WindowsSecurity
    extend Puppet::Util::Windows::Security
  end
end

describe Puppet::Type.type(:file).provider(:windows), :if => Puppet.features.microsoft_windows? do
  include PuppetSpec::Files

  let(:path) { tmpfile('windows_file_spec') }
  let(:resource) { Puppet::Type.type(:file).new :path => path, :mode => 0777, :provider => described_class.name }
  let(:provider) { resource.provider }

  describe "#mode" do
    it "should return a string with the higher-order bits stripped away" do
      FileUtils.touch(path)
      WindowsSecurity.set_mode(0644, path)

      provider.mode.should == '644'
    end

    it "should return absent if the file doesn't exist" do
      provider.mode.should == :absent
    end
  end

  describe "#mode=" do
    it "should chmod the file to the specified value" do
      FileUtils.touch(path)
      WindowsSecurity.set_mode(0644, path)

      provider.mode = '0755'

      provider.mode.should == '755'
    end

    it "should pass along any errors encountered" do
      expect do
        provider.mode = '644'
      end.to raise_error(Puppet::Error, /failed to set mode/)
    end
  end
end
