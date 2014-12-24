#! /usr/bin/env ruby
#
# Unit testing for the OpenWrt service Provider
#
require 'spec_helper'

describe Puppet::Type.type(:service).provider(:openwrt), :if => Puppet.features.posix? do

  let(:resource) do
    resource = stub 'resource'
    resource.stubs(:[]).returns(nil)
    resource.stubs(:[]).with(:name).returns "myservice"
    resource.stubs(:[]).with(:path).returns ["/etc/init.d"]

    resource
  end

  let(:provider) do
    provider = described_class.new
    provider.stubs(:get).with(:hasstatus).returns false

    provider
  end


  before :each do
    resource.stubs(:provider).returns provider
    provider.resource = resource

    FileTest.stubs(:file?).with('/etc/rc.common').returns true
    FileTest.stubs(:executable?).with('/etc/rc.common').returns true

    # All OpenWrt tests operate on the init script directly. It must exist.
    File.stubs(:directory?).with('/etc/init.d').returns true

    Puppet::FileSystem.stubs(:exist?).with('/etc/init.d/myservice').returns true
    FileTest.stubs(:file?).with('/etc/init.d/myservice').returns true
    FileTest.stubs(:executable?).with('/etc/init.d/myservice').returns true
  end

  operatingsystem = 'openwrt'
  it "should be the default provider on #{operatingsystem}" do
    Facter.expects(:value).with(:operatingsystem).returns(operatingsystem)
    expect(described_class.default?).to be_truthy
  end

  # test self.instances
  describe "when getting all service instances" do

    let(:services) {['dnsmasq', 'dropbear', 'firewall', 'led', 'puppet', 'uhttpd' ]}

    before :each do
      Dir.stubs(:entries).returns services
      FileTest.stubs(:directory?).returns(true)
      FileTest.stubs(:executable?).returns(true)
    end
    it "should return instances for all services" do
      services.each do |inst|
        described_class.expects(:new).with{|hash| hash[:name] == inst && hash[:path] == '/etc/init.d'}.returns("#{inst}_instance")
      end
      results = services.collect {|x| "#{x}_instance"}
      expect(described_class.instances).to eq(results)
    end
  end

  it "should have an enabled? method" do
    expect(provider).to respond_to(:enabled?)
  end

  it "should have an enable method" do
    expect(provider).to respond_to(:enable)
  end

  it "should have a disable method" do
    expect(provider).to respond_to(:disable)
  end

  [:start, :stop, :restart].each do |method|
    it "should have a #{method} method" do
      expect(provider).to respond_to(method)
    end
    describe "when running #{method}" do

      it "should use any provided explicit command" do
        resource.stubs(:[]).with(method).returns "/user/specified/command"
        provider.expects(:execute).with { |command, *args| command == ["/user/specified/command"] }
        provider.send(method)
      end

      it "should execute the init script with #{method} when no explicit command is provided" do
        resource.stubs(:[]).with("has#{method}".intern).returns :true
        provider.expects(:execute).with { |command, *args| command ==  ['/etc/init.d/myservice', method ]}
        provider.send(method)
      end
    end
  end

  describe "when checking status" do
    it "should consider the service :running if it has a pid" do
      provider.expects(:getpid).returns "1234"
      expect(provider.status).to eq(:running)
    end
    it "should consider the service :stopped if it doesn't have a pid" do
      provider.expects(:getpid).returns nil
      expect(provider.status).to eq(:stopped)
    end
  end

end
