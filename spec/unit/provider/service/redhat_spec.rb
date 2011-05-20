#!/usr/bin/env rspec
#
# Unit testing for the RedHat service Provider
#
require 'spec_helper'

provider_class = Puppet::Type.type(:service).provider(:redhat)

describe provider_class do

  before :each do
    @class = Puppet::Type.type(:service).provider(:redhat)
    @resource = stub 'resource'
    @resource.stubs(:[]).returns(nil)
    @resource.stubs(:[]).with(:name).returns "myservice"
    @provider = provider_class.new
    @resource.stubs(:provider).returns @provider
    @provider.resource = @resource
    @provider.stubs(:get).with(:hasstatus).returns false
    FileTest.stubs(:file?).with('/sbin/service').returns true
    FileTest.stubs(:executable?).with('/sbin/service').returns true
  end

  # test self.instances
  describe "when getting all service instances" do
    before :each do
      @services = ['one', 'two', 'three', 'four', 'kudzu', 'functions', 'halt', 'killall', 'single', 'linuxconf']
      @not_services = ['functions', 'halt', 'killall', 'single', 'linuxconf']
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
    it "should call service status when initialized from provider" do
      @resource.stubs(:[]).with(:status).returns nil
      @provider.stubs(:get).with(:hasstatus).returns true
      @provider.expects(:execute).with{|command, *args| command == ['/sbin/service', 'myservice', 'status']}
      @provider.send(:status)
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

  [:start, :stop, :status, :restart].each do |method|
    it "should have a #{method} method" do
      @provider.should respond_to(method)
    end
    describe "when running #{method}" do

      it "should use any provided explicit command" do
        @resource.stubs(:[]).with(method).returns "/user/specified/command"
        @provider.expects(:execute).with { |command, *args| command == ["/user/specified/command"] }
        @provider.send(method)
      end

      it "should execute the service script with #{method} when no explicit command is provided" do
        @resource.stubs(:[]).with("has#{method}".intern).returns :true
        @provider.expects(:execute).with { |command, *args| command ==  ['/sbin/service', 'myservice', method.to_s]}
        @provider.send(method)
      end
    end
  end

  describe "when checking status" do
    describe "when hasstatus is :true" do
      before :each do
        @resource.stubs(:[]).with(:hasstatus).returns :true
      end
      it "should execute the service script with fail_on_failure false" do
        @provider.expects(:texecute).with(:status, ['/sbin/service', 'myservice', 'status'], false)
        @provider.status
      end
      it "should consider the process running if the command returns 0" do
        @provider.expects(:texecute).with(:status, ['/sbin/service', 'myservice', 'status'], false)
        $CHILD_STATUS.stubs(:exitstatus).returns(0)
        @provider.status.should == :running
      end
      [-10,-1,1,10].each { |ec|
        it "should consider the process stopped if the command returns something non-0" do
          @provider.expects(:texecute).with(:status, ['/sbin/service', 'myservice', 'status'], false)
          $CHILD_STATUS.stubs(:exitstatus).returns(ec)
          @provider.status.should == :stopped
        end
      }
    end
    describe "when hasstatus is not :true" do
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

  describe "when restarting and hasrestart is not :true" do
    it "should stop and restart the process with the server script" do
      @provider.expects(:texecute).with(:stop,  ['/sbin/service', 'myservice', 'stop'],  true)
      @provider.expects(:texecute).with(:start, ['/sbin/service', 'myservice', 'start'], true)
      @provider.restart
    end
  end
end
