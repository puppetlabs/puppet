#! /usr/bin/env ruby
#
# Unit testing for the OpenWrt service Provider
#
require 'spec_helper'

provider_class = Puppet::Type.type(:service).provider(:openwrt)

describe provider_class, :as_platform => :posix do

  before :each do
    @class = Puppet::Type.type(:service).provider(:openwrt)
    @resource = stub 'resource'
    @resource.stubs(:[]).returns(nil)
    @resource.stubs(:[]).with(:name).returns "myservice"
    @resource.stubs(:[]).with(:path).returns [ "/etc/init.d/" ]
    @provider = provider_class.new
    @resource.stubs(:provider).returns @provider
    @provider.resource = @resource
    @provider.stubs(:get).with(:hasstatus).returns false
    FileTest.stubs(:file?).with('/etc/rc.common').returns true
    FileTest.stubs(:executable?).with('/etc/rc.common').returns true
    
    # All OpenWrt tests operate on the init script directly. It must exist. 
    File.stubs(:stat).with('/etc/init.d/myservice')
    FileTest.stubs(:file?).with('/etc/init.d/myservice').returns true
    FileTest.stubs(:executable?).with('/etc/init.d/myservice').returns true
  end

  operatingsystem = 'openwrt'
  it "should be the default provider on #{operatingsystem}" do
    Facter.expects(:value).with(:operatingsystem).returns(operatingsystem)
    provider_class.default?.should be_true
  end

  # test self.instances
  describe "when getting all service instances" do
    before :each do
      @services = ['boot', 'dnsmasq', 'dropbear', 'firewall', 'led', 'puppet', 'uhttpd' ]
      @not_services = ['boot']
      Dir.stubs(:entries).returns @services
      FileTest.stubs(:directory?).returns(true)
      FileTest.stubs(:executable?).returns(true)
    end
    it "should return instances for all services" do
      (@services-@not_services).each do |inst|
        @class.expects(:new).with{|hash| hash[:name] == inst && hash[:path] == '/etc/init.d'}.returns("#{inst}_instance")
      end
      results = (@services-@not_services).collect {|x| "#{x}_instance"}
      @class.instances.should == results
    end
  end

  it "should have an enabled? method" do
    @provider.should respond_to(:enabled?)
  end

  it "should have an enable method" do
    @provider.should respond_to(:enable)
  end

  it "should have a disable method" do
    @provider.should respond_to(:disable)
  end

  [:start, :stop, :restart].each do |method|
    it "should have a #{method} method" do
      @provider.should respond_to(method)
    end
    describe "when running #{method}" do

      it "should use any provided explicit command" do
        @resource.stubs(:[]).with(method).returns "/user/specified/command"
        @provider.expects(:execute).with { |command, *args| command == ["/user/specified/command"] }
        @provider.send(method)
      end

      it "should execute the init script with #{method} when no explicit command is provided" do
        @resource.stubs(:[]).with("has#{method}".intern).returns :true
        @provider.expects(:execute).with { |command, *args| command ==  ['/etc/init.d/myservice', method ]}
        @provider.send(method)
      end
    end
  end

  describe "when checking status" do
    it "should consider the service :running if it has a pid" do
      @provider.expects(:getpid).returns "1234"
      @provider.status.should == :running
    end
    it "should consider the service :stopped if it doesn't have a pid" do
      @provider.expects(:getpid).returns nil
      @provider.status.should == :stopped
    end
  end

end
