#! /usr/bin/env ruby
#
# Unit testing for the Runit service Provider
#
# author Brice Figureau
#
require 'spec_helper'

provider_class = Puppet::Type.type(:service).provider(:runit)

describe provider_class do

  before(:each) do
    # Create a mock resource
    @resource = stub 'resource'

    @provider = provider_class.new
    @servicedir = "/etc/service"
    @provider.servicedir=@servicedir
    @daemondir = "/etc/sv"
    @provider.class.defpath=@daemondir

    # A catch all; no parameters set
    @resource.stubs(:[]).returns(nil)

    # But set name, source and path (because we won't run
    # the thing that will fetch the resource path from the provider)
    @resource.stubs(:[]).with(:name).returns "myservice"
    @resource.stubs(:[]).with(:ensure).returns :enabled
    @resource.stubs(:[]).with(:path).returns @daemondir
    @resource.stubs(:ref).returns "Service[myservice]"

    @provider.stubs(:sv)

    @provider.stubs(:resource).returns @resource
  end

  it "should have a restart method" do
    expect(@provider).to respond_to(:restart)
  end

  it "should have a restartcmd method" do
    expect(@provider).to respond_to(:restartcmd)
  end

  it "should have a start method" do
    expect(@provider).to respond_to(:start)
  end

  it "should have a stop method" do
    expect(@provider).to respond_to(:stop)
  end

  it "should have an enabled? method" do
    expect(@provider).to respond_to(:enabled?)
  end

  it "should have an enable method" do
    expect(@provider).to respond_to(:enable)
  end

  it "should have a disable method" do
    expect(@provider).to respond_to(:disable)
  end

  describe "when starting" do
    it "should enable the service if it is not enabled" do
      @provider.stubs(:sv)

      @provider.expects(:enabled?).returns :false
      @provider.expects(:enable)
      @provider.stubs(:sleep)

      @provider.start
    end

    it "should execute external command 'sv start /etc/service/myservice'" do
      @provider.stubs(:enabled?).returns :true
      @provider.expects(:sv).with("start", "/etc/service/myservice")
      @provider.start
    end
  end

  describe "when stopping" do
    it "should execute external command 'sv stop /etc/service/myservice'" do
      @provider.expects(:sv).with("stop", "/etc/service/myservice")
      @provider.stop
    end
  end

  describe "when restarting" do
    it "should call 'sv restart /etc/service/myservice'" do
      @provider.expects(:sv).with("restart","/etc/service/myservice")
      @provider.restart
    end
  end

  describe "when enabling" do
    it "should create a symlink between daemon dir and service dir", :if => Puppet.features.manages_symlinks? do
      daemon_path = File.join(@daemondir,"myservice")
      service_path = File.join(@servicedir,"myservice")
      Puppet::FileSystem.expects(:symlink?).with(service_path).returns(false)
      Puppet::FileSystem.expects(:symlink).with(daemon_path, File.join(@servicedir,"myservice")).returns(0)
      @provider.enable
    end
  end

  describe "when disabling" do
    it "should remove the '/etc/service/myservice' symlink" do
      path = File.join(@servicedir,"myservice")
#      mocked_file = mock(path, :symlink? => true)
      FileTest.stubs(:directory?).returns(false)
      Puppet::FileSystem.expects(:symlink?).with(path).returns(true) # mocked_file)
      Puppet::FileSystem.expects(:unlink).with(path).returns(0)
      @provider.disable
    end
  end

  describe "when checking status" do
    it "should call the external command 'sv status /etc/sv/myservice'" do
      @provider.expects(:sv).with('status',File.join(@daemondir,"myservice"))
      @provider.status
    end
  end

  describe "when checking status" do
    it "and sv status fails, properly raise a Puppet::Error" do
      @provider.expects(:sv).with('status',File.join(@daemondir,"myservice")).raises(Puppet::ExecutionFailure, "fail: /etc/sv/myservice: file not found")
      expect { @provider.status }.to raise_error(Puppet::Error, 'Could not get status for service Service[myservice]: fail: /etc/sv/myservice: file not found')
    end
    it "and sv status returns up, then return :running" do
      @provider.expects(:sv).with('status',File.join(@daemondir,"myservice")).returns("run: /etc/sv/myservice: (pid 9029) 6s")
      expect(@provider.status).to eq(:running)
    end
    it "and sv status returns not running, then return :stopped" do
      @provider.expects(:sv).with('status',File.join(@daemondir,"myservice")).returns("fail: /etc/sv/myservice: runsv not running")
      expect(@provider.status).to eq(:stopped)
    end
    it "and sv status returns a warning, then return :stopped" do
      @provider.expects(:sv).with('status',File.join(@daemondir,"myservice")).returns("warning: /etc/sv/myservice: unable to open supervise/ok: file does not exist")
      expect(@provider.status).to eq(:stopped)
    end
  end

end
