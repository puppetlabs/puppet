#! /usr/bin/env ruby
#
# Unit testing for the SMF service Provider
#
# author Dominic Cleal
#
require 'spec_helper'

provider_class = Puppet::Type.type(:service).provider(:smf)

describe provider_class, :if => Puppet.features.posix? do

  before(:each) do
    # Create a mock resource
    @resource = Puppet::Type.type(:service).new(
      :name => "/system/myservice", :ensure => :running, :enable => :true)
    @provider = provider_class.new(@resource)

    FileTest.stubs(:file?).with('/usr/sbin/svcadm').returns true
    FileTest.stubs(:executable?).with('/usr/sbin/svcadm').returns true
    FileTest.stubs(:file?).with('/usr/sbin/svccfg').returns true
    FileTest.stubs(:executable?).with('/usr/sbin/svccfg').returns true
    FileTest.stubs(:file?).with('/usr/bin/svcs').returns true
    FileTest.stubs(:executable?).with('/usr/bin/svcs').returns true
    Facter.stubs(:value).with(:operatingsystem).returns('Solaris')
    Facter.stubs(:value).with(:osfamily).returns('Solaris')
    Facter.stubs(:value).with(:operatingsystemrelease).returns '11.2'
  end

  describe ".instances" do
    it "should have an instances method" do
      expect(provider_class).to respond_to :instances
    end

    it "should get a list of services (excluding legacy)" do
      provider_class.expects(:svcs).with('-H', '-o', 'state,fmri').returns File.read(my_fixture('svcs.out'))
      instances = provider_class.instances.map { |p| {:name => p.get(:name), :ensure => p.get(:ensure)} }
      # we dont manage legacy
      expect(instances.size).to eq(3)
      expect(instances[0]).to eq({:name => 'svc:/system/svc/restarter:default', :ensure => :running })
      expect(instances[1]).to eq({:name => 'svc:/network/cswrsyncd:default', :ensure => :maintenance })
      expect(instances[2]).to eq({:name => 'svc:/network/dns/client:default', :ensure => :degraded })
    end
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

  describe "when checking status" do
    it "should call the external command 'svcs /system/myservice' once" do
      @provider.expects(:svcs).with('-H', '-o', 'state,nstate', "/system/myservice").returns("online\t-")
      @provider.status
    end
    it "should return absent if svcs can't find the service" do
      @provider.stubs(:svcs).raises(Puppet::ExecutionFailure.new("no svc found"))
      expect(@provider.status).to eq(:absent)
    end
    it "should return running if online in svcs output" do
      @provider.stubs(:svcs).returns("online\t-")
      expect(@provider.status).to eq(:running)
    end
    it "should return stopped if disabled in svcs output" do
      @provider.stubs(:svcs).returns("disabled\t-")
      expect(@provider.status).to eq(:stopped)
    end
    it "should return maintenance if in maintenance in svcs output" do
      @provider.stubs(:svcs).returns("maintenance\t-")
      expect(@provider.status).to eq(:maintenance)
    end
    it "should return degraded if in degraded in svcs output" do
      @provider.stubs(:svcs).returns("degraded\t-")
      expect(@provider.status).to eq(:degraded)
    end
    it "should return target state if transitioning in svcs output" do
      @provider.stubs(:svcs).returns("online\tdisabled")
      expect(@provider.status).to eq(:stopped)
    end
    it "should throw error if it's a legacy service in svcs output" do
      @provider.stubs(:svcs).returns("legacy_run\t-")
      expect { @provider.status }.to raise_error(Puppet::Error, "Cannot manage legacy services through SMF")
    end
  end

  describe "when starting" do
    it "should enable the service if it is not enabled" do
      @provider.expects(:status).returns :stopped
      @provider.expects(:texecute).with(:start, ['/usr/sbin/svcadm', :enable, '-rs', '/system/myservice'], true)
      @provider.expects(:wait).with('online')
      @provider.start
    end

    it "should always execute external command 'svcadm enable /system/myservice'" do
      @provider.expects(:status).returns :running
      @provider.expects(:texecute).with(:start, ['/usr/sbin/svcadm', :enable, '-rs', '/system/myservice'], true)
      @provider.expects(:wait).with('online')
      @provider.start
    end

    it "should execute external command 'svcadm clear /system/myservice' if in maintenance" do
      @provider.stubs(:status).returns :maintenance
      @provider.expects(:texecute).with(:start, ["/usr/sbin/svcadm", :clear, "/system/myservice"], true)
      @provider.expects(:wait).with('online')
      @provider.start
    end

    it "should execute external command 'svcadm clear /system/myservice' if in degraded" do
      @provider.stubs(:status).returns :degraded
      @provider.expects(:texecute).with(:start, ["/usr/sbin/svcadm", :clear, "/system/myservice"], true)
      @provider.expects(:wait).with('online')
      @provider.start
    end

    it "should error if timeout occurs while starting the service" do
      @provider.expects(:status).returns :stopped
      @provider.expects(:texecute).with(:start, ["/usr/sbin/svcadm", :enable, '-rs', "/system/myservice"], true)
      Timeout.expects(:timeout).with(60).raises(Timeout::Error)
      expect { @provider.start }.to raise_error Puppet::Error, ('Timed out waiting for /system/myservice to transition states')
    end
  end

  describe "when starting a service with a manifest" do
    before(:each) do
      @resource = Puppet::Type.type(:service).new(:name => "/system/myservice", :ensure => :running, :enable => :true, :manifest => "/tmp/myservice.xml")
      @provider = provider_class.new(@resource)
      $CHILD_STATUS.stubs(:exitstatus).returns(1)
    end

    it "should import the manifest if service is missing" do
      @provider.expects(:svcs).with('-l', '/system/myservice').raises(Puppet::ExecutionFailure, "Exited 1")
      @provider.expects(:svccfg).with(:import, "/tmp/myservice.xml")
      @provider.expects(:texecute).with(:start, ["/usr/sbin/svcadm", :enable, '-rs', "/system/myservice"], true)
      @provider.expects(:wait).with('online')
      @provider.expects(:svcs).with('-H', '-o', 'state,nstate', "/system/myservice").returns("online\t-")
      @provider.start
    end

    it "should handle failures if importing a manifest" do
      @provider.expects(:svcs).with('-l', '/system/myservice').raises(Puppet::ExecutionFailure, "Exited 1")
      @provider.expects(:svccfg).raises(Puppet::ExecutionFailure.new("can't svccfg import"))
      expect { @provider.start }.to raise_error(Puppet::Error, "Cannot config /system/myservice to enable it: can't svccfg import")
    end
  end

  describe "when stopping" do
    it "should execute external command 'svcadm disable /system/myservice'" do
      @provider.stubs(:status).returns :running
      @provider.expects(:texecute).with(:stop, ["/usr/sbin/svcadm", :disable, '-s', "/system/myservice"], true)
      @provider.expects(:wait).with('offline', 'disabled', 'uninitialized')
      @provider.stop
    end

    it "should error if timeout occurs while stopping the service" do
      @provider.stubs(:status).returns :running
      @provider.expects(:texecute).with(:stop, ["/usr/sbin/svcadm", :disable, '-s', "/system/myservice"], true)
      Timeout.expects(:timeout).with(60).raises(Timeout::Error)
      expect { @provider.stop }.to raise_error Puppet::Error, ('Timed out waiting for /system/myservice to transition states')
    end
  end

  describe "when restarting" do

    it "should error if timeout occurs while restarting the service" do
      @provider.expects(:texecute).with(:restart, ["/usr/sbin/svcadm", :restart, '-s', "/system/myservice"], true)
      Timeout.expects(:timeout).with(60).raises(Timeout::Error)
      expect { @provider.restart }.to raise_error Puppet::Error, ('Timed out waiting for /system/myservice to transition states')
    end

    context 'with :operatingsystemrelease == 10_u10' do
      it "should call 'svcadm restart /system/myservice'" do
        Facter.stubs(:value).with(:operatingsystemrelease).returns '10_u10'
        @provider.expects(:texecute).with(:restart, ["/usr/sbin/svcadm", :restart, "/system/myservice"], true)
        @provider.expects(:wait).with('online')
        @provider.restart
      end
    end

    context 'with :operatingsystemrelease == 11.2' do
      it "should call 'svcadm restart -s /system/myservice'" do
        Facter.stubs(:value).with(:operatingsystemrelease).returns '11.2'
        @provider.expects(:texecute).with(:restart, ["/usr/sbin/svcadm", :restart, '-s', "/system/myservice"], true)
        @provider.expects(:wait).with('online')
        @provider.restart
      end
    end

    context 'with :operatingsystemrelease > 11.2' do
      it "should call 'svcadm restart -s /system/myservice'" do
        Facter.stubs(:value).with(:operatingsystemrelease).returns '11.3'
        @provider.expects(:texecute).with(:restart, ["/usr/sbin/svcadm", :restart, '-s', "/system/myservice"], true)
        @provider.expects(:wait).with('online')
        @provider.restart
      end
    end

  end
end
