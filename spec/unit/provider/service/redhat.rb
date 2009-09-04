#!/usr/bin/env ruby
#
# Unit testing for the RedHat service Provider
#

require File.dirname(__FILE__) + '/../../../spec_helper'

provider_class = Puppet::Type.type(:service).provider(:redhat)

describe provider_class do

    before(:each) do
        # Create a mock resource
        @resource = stub 'resource'

        @provider = provider_class.new
        # A catch all; no parameters set
        @resource.stubs(:[]).returns(nil)

        # But set name, source and path (because we won't run
        # the thing that will fetch the resource path from the provider)
        @resource.stubs(:[]).with(:name).returns "myservice"
        @resource.stubs(:[]).with(:ensure).returns :enabled
        @resource.stubs(:[]).with(:path).returns ["/service/path","/alt/service/path"]
        @resource.stubs(:ref).returns "Service[myservice]"
        
        @provider.stubs(:resource).returns @resource
        @provider.resource = @resource
    end

    it "should have a start method" do
        @provider.should respond_to(:start)
    end

    it "should have a stop method" do
        @provider.should respond_to(:stop)
    end

    it "should have a restart method" do
        @provider.should respond_to(:restart)
    end

    it "should have a status method" do
        @provider.should respond_to(:status)
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

    describe "when starting" do
        it "should execute the service script with start" do
            @provider.expects(:texecute).with(:start, ['/sbin/service', 'myservice', 'start'], true)
            @provider.start
        end
    end

    describe "when stopping" do
        it "should execute the init script with stop" do
            @provider.expects(:texecute).with(:stop, ['/sbin/service', 'myservice', 'stop'], true)
            @provider.stop
        end
    end

    describe "when checking status" do
        describe "when hasstatus is :true" do
            before :each do
                @resource.stubs(:[]).with(:hasstatus).returns :true
            end
            it "should execute the command" do
                @provider.expects(:texecute).with(:status, ['/sbin/service', 'myservice', 'status'], false)
                @provider.status
            end
            it "should consider the process running if the command returns 0" do
                @provider.expects(:texecute).with(:status, ['/sbin/service', 'myservice', 'status'], false)
                $?.stubs(:exitstatus).returns(0)
                @provider.status.should == :running
            end
            [-10,-1,1,10].each { |ec|
                it "should consider the process stopped if the command returns something non-0" do
                    @provider.expects(:texecute).with(:status, ['/sbin/service', 'myservice', 'status'], false)
                    $?.stubs(:exitstatus).returns(ec)
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

    describe "when restarting" do
        describe "when hasrestart is :true" do
            before :each do
                @resource.stubs(:[]).with(:hasrestart).returns :true
            end
            it "should execute the command" do
                @provider.expects(:texecute).with(:restart, ['/sbin/service', 'myservice', 'restart'], true)
                $?.stubs(:exitstatus).returns(0)
                @provider.restart
            end
        end
        describe "when hasrestart is not :true" do
            it "should stop and restart the process" do
                @provider.expects(:texecute).with(:stop,  ['/sbin/service', 'myservice', 'stop'],  true)
                @provider.expects(:texecute).with(:start, ['/sbin/service', 'myservice', 'start'], true)
                $?.stubs(:exitstatus).returns(0)
                @provider.restart
            end
        end
    end
end
