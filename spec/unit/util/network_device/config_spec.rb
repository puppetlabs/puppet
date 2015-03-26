#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/network_device/config'

describe Puppet::Util::NetworkDevice::Config do
  include PuppetSpec::Files

  before(:each) do
    Puppet[:deviceconfig] = tmpfile('deviceconfig')
  end

  describe "when parsing device" do
    let(:config) { Puppet::Util::NetworkDevice::Config.new }

    def write_device_config(*lines)
      File.open(Puppet[:deviceconfig], 'w') {|f| f.puts lines}
    end

    it "should skip comments" do
      write_device_config('  # comment')

      expect(config.devices).to be_empty
    end

    it "should increment line number even on commented lines" do
      write_device_config('  # comment','[router.puppetlabs.com]')

      expect(config.devices).to be_include('router.puppetlabs.com')
    end

    it "should skip blank lines" do
      write_device_config('  ')

      expect(config.devices).to be_empty
    end

    it "should produce the correct line number" do
      write_device_config('  ', '[router.puppetlabs.com]')

      expect(config.devices['router.puppetlabs.com'].line).to eq(2)
    end

    it "should throw an error if the current device already exists" do
      write_device_config('[router.puppetlabs.com]', '[router.puppetlabs.com]')

    end

    it "should accept device certname containing dashes" do
      write_device_config('[router-1.puppetlabs.com]')

      expect(config.devices).to include('router-1.puppetlabs.com')
    end

    it "should create a new device for each found device line" do
      write_device_config('[router.puppetlabs.com]', '[swith.puppetlabs.com]')

      expect(config.devices.size).to eq(2)
    end

    it "should parse the device type" do
      write_device_config('[router.puppetlabs.com]', 'type cisco')

      expect(config.devices['router.puppetlabs.com'].provider).to eq('cisco')
    end

    it "should parse the device url" do
      write_device_config('[router.puppetlabs.com]', 'type cisco', 'url ssh://test/')

      expect(config.devices['router.puppetlabs.com'].url).to eq('ssh://test/')
    end

    it "should error with a malformed device url" do
      write_device_config('[router.puppetlabs.com]', 'type cisco', 'url ssh://test node/')

      expect { config.devices['router.puppetlabs.com'] }.to raise_error Puppet::Error
    end

    it "should parse the debug mode" do
      write_device_config('[router.puppetlabs.com]', 'type cisco', 'url ssh://test/', 'debug')

      expect(config.devices['router.puppetlabs.com'].options).to eq({ :debug => true })
    end

    it "should set the debug mode to false by default" do
      write_device_config('[router.puppetlabs.com]', 'type cisco', 'url ssh://test/')

      expect(config.devices['router.puppetlabs.com'].options).to eq({ :debug => false })
    end
  end

end
