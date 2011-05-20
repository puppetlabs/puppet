#!/usr/bin/env rspec
#
# Unit testing for the Init service Provider
#

require 'spec_helper'

provider_class = Puppet::Type.type(:service).provider(:init)

describe provider_class do

  before :each do
    @class = Puppet::Type.type(:service).provider(:init)
    @resource = stub 'resource'
    @resource.stubs(:[]).returns(nil)
    @resource.stubs(:[]).with(:name).returns "myservice"
#        @resource.stubs(:[]).with(:ensure).returns :enabled
    @resource.stubs(:[]).with(:path).returns ["/service/path","/alt/service/path"]
#        @resource.stubs(:ref).returns "Service[myservice]"
    File.stubs(:directory?).returns(true)

    @provider = provider_class.new
    @provider.resource = @resource
  end

  describe "when getting all service instances" do
    before :each do
      @services = ['one', 'two', 'three', 'four']
      Dir.stubs(:entries).returns @services
      FileTest.stubs(:directory?).returns(true)
      FileTest.stubs(:executable?).returns(true)
      @class.stubs(:defpath).returns('tmp')
    end
    it "should return instances for all services" do
      @services.each do |inst|
        @class.expects(:new).with{|hash| hash[:name] == inst}.returns("#{inst}_instance")
      end
      results = @services.collect {|x| "#{x}_instance"}
      @class.instances.should == results
    end
    it "should omit an array of services from exclude list" do
      exclude = ['two', 'four']
      (@services-exclude).each do |inst|
        @class.expects(:new).with{|hash| hash[:name] == inst}.returns("#{inst}_instance")
      end
      results = (@services-exclude).collect {|x| "#{x}_instance"}
      @class.get_services(@class.defpath, exclude).should == results
    end
    it "should omit a single service from the exclude list", :'fails_on_ruby_1.9.2' => true do
      exclude = 'two'
      (@services-exclude.to_a).each do |inst|
        @class.expects(:new).with{|hash| hash[:name] == inst}.returns("#{inst}_instance")
      end
      results = @services.reject{|x| x==exclude }.collect {|x| "#{x}_instance"}
      @class.get_services(@class.defpath, exclude).should == results
    end
    it "should use defpath" do
      @services.each do |inst|
        @class.expects(:new).with{|hash| hash[:path] == @class.defpath}.returns("#{inst}_instance")
      end
      results = @services.sort.collect {|x| "#{x}_instance"}
      @class.instances.sort.should == results
    end
    it "should set hasstatus to true for providers" do
      @services.each do |inst|
        @class.expects(:new).with{|hash| hash[:name] == inst && hash[:hasstatus] == true}.returns("#{inst}_instance")
      end
      results = @services.collect {|x| "#{x}_instance"}
      @class.instances.should == results
    end
  end

  describe "when searching for the init script" do
    it "should discard paths that do not exist" do
      File.stubs(:exist?).returns(false)
      File.stubs(:directory?).returns(false)
      @provider.paths.should be_empty
    end

    it "should discard paths that are not directories" do
      File.stubs(:exist?).returns(true)
      File.stubs(:directory?).returns(false)
      @provider.paths.should be_empty
    end

    it "should be able to find the init script in the service path" do
      File.stubs(:stat).raises(Errno::ENOENT.new('No such file or directory'))
      File.expects(:stat).with("/service/path/myservice").returns true
      @provider.initscript.should == "/service/path/myservice"
    end
    it "should be able to find the init script in the service path" do
      File.stubs(:stat).raises(Errno::ENOENT.new('No such file or directory'))
      File.expects(:stat).with("/alt/service/path/myservice").returns true
      @provider.initscript.should == "/alt/service/path/myservice"
    end
    it "should fail if the service isn't there" do
      lambda { @provider.initscript }.should raise_error(Puppet::Error, "Could not find init script for 'myservice'")
    end
  end

  describe "if the init script is present" do
    before :each do
      File.stubs(:stat).with("/service/path/myservice").returns true
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

        it "should pass #{method} to the init script when no explicit command is provided" do
          @resource.stubs(:[]).with("has#{method}".intern).returns :true
          @provider.expects(:execute).with { |command, *args| command ==  ["/service/path/myservice",method]}
          @provider.send(method)
        end
      end
    end

    describe "when checking status" do
      describe "when hasstatus is :true" do
        before :each do
          @resource.stubs(:[]).with(:hasstatus).returns :true
        end
        it "should execute the command" do
          @provider.expects(:texecute).with(:status, ['/service/path/myservice', :status], false).returns("")
          @provider.status
        end
        it "should consider the process running if the command returns 0" do
          @provider.expects(:texecute).with(:status, ['/service/path/myservice', :status], false).returns("")
          $CHILD_STATUS.stubs(:exitstatus).returns(0)
          @provider.status.should == :running
        end
        [-10,-1,1,10].each { |ec|
          it "should consider the process stopped if the command returns something non-0" do
            @provider.expects(:texecute).with(:status, ['/service/path/myservice', :status], false).returns("")
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
      it "should stop and restart the process" do
        @provider.expects(:texecute).with(:stop, ['/service/path/myservice', :stop ], true).returns("")
        @provider.expects(:texecute).with(:start,['/service/path/myservice', :start], true).returns("")
        $CHILD_STATUS.stubs(:exitstatus).returns(0)
        @provider.restart
      end
    end

  end
end
