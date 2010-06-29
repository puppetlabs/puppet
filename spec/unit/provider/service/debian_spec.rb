#!/usr/bin/env ruby
#
# Unit testing for the debian service provider
#

require File.dirname(__FILE__) + '/../../../spec_helper'

provider_class = Puppet::Type.type(:service).provider(:debian)

describe provider_class do

    before(:each) do
        # Create a mock resource
        @resource = stub 'resource'

        @provider = provider_class.new

        # A catch all; no parameters set
        @resource.stubs(:[]).returns(nil)

        # But set name, source and path
        @resource.stubs(:[]).with(:name).returns "myservice"
        @resource.stubs(:[]).with(:ensure).returns :enabled
        @resource.stubs(:ref).returns "Service[myservice]"

        @provider.resource = @resource

        @provider.stubs(:command).with(:update_rc).returns "update_rc"
        @provider.stubs(:command).with(:invoke_rc).returns "invoke_rc"

        @provider.stubs(:update_rc)
        @provider.stubs(:invoke_rc)
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

    describe "when enabling" do
        it "should call update-rc.d twice" do
            @provider.expects(:update_rc).twice
            @provider.enable
        end
    end

    describe "when disabling" do
        it "should call update-rc.d twice" do
            @provider.expects(:update_rc).twice
            @provider.disable
        end
    end
    
    describe "when checking whether it is enabled" do
        it "should call Kernel.system() with the appropriate parameters" do
            @provider.expects(:system).with("/usr/sbin/invoke-rc.d", "--quiet", "--query", @resource[:name], "start").once
            @provider.enabled?
        end
        
        it "should return true when invoke-rc.d exits with 104 status" do
            @provider.stubs(:system)
            $?.stubs(:exitstatus).returns(104)
            @provider.enabled?.should == :true
        end
        
        it "should return true when invoke-rc.d exits with 106 status" do
            @provider.stubs(:system)
            $?.stubs(:exitstatus).returns(106)
            @provider.enabled?.should == :true
        end
        
        # pick a range of non-[104.106] numbers, strings and booleans to test with.
        [-100, -1, 0, 1, 100, "foo", "", :true, :false].each do |exitstatus|
            it "should return false when invoke-rc.d exits with #{exitstatus} status" do
                @provider.stubs(:system)
                $?.stubs(:exitstatus).returns(exitstatus)
                @provider.enabled?.should == :false
            end
        end
    end

 end
