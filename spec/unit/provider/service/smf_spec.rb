require 'spec_helper'

describe Puppet::Type.type(:service).provider(:smf), :if => Puppet.features.posix? do
  before(:each) do
    # Create a mock resource
    @resource = Puppet::Type.type(:service).new(
      :name => "/system/myservice", :ensure => :running, :enable => :true)
    @provider = described_class.new(@resource)

    FileTest.stubs(:file?).with('/usr/sbin/svcadm').returns true
    FileTest.stubs(:executable?).with('/usr/sbin/svcadm').returns true
    FileTest.stubs(:file?).with('/usr/bin/svcs').returns true
    FileTest.stubs(:executable?).with('/usr/bin/svcs').returns true
    Facter.stubs(:value).with(:operatingsystem).returns('Solaris')
    Facter.stubs(:value).with(:osfamily).returns('Solaris')
    Facter.stubs(:value).with(:operatingsystemrelease).returns '11.2'
  end

  context ".instances" do
    it "should have an instances method" do
      expect(described_class).to respond_to :instances
    end

    it "should get a list of services (excluding legacy)" do
      described_class.expects(:svcs).with('-H', '-o', 'state,fmri').returns File.read(my_fixture('svcs.out'))
      instances = described_class.instances.map { |p| {:name => p.get(:name), :ensure => p.get(:ensure)} }
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
    before(:each) do
      @provider.stubs(:complete_service?).returns(true)
    end

    it "should call the external command 'svcs /system/myservice' once" do
      @provider.expects(:svcs).with('-H', '-o', 'state,nstate', "/system/myservice").returns("online\t-")
      @provider.status
    end
    it "should return stopped if svcs can't find the service" do
      @provider.stubs(:svcs).raises(Puppet::ExecutionFailure.new("no svc found"))
      expect(@provider.status).to eq(:stopped)
    end
    it "should return stopped for an incomplete service on Solaris 11" do
      Facter.stubs(:value).with(:operatingsystemrelease).returns('11.3')
      @provider.stubs(:complete_service?).returns(false)
      expect(@provider.status).to eq(:stopped)
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

  context "when starting" do
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

  context "when starting a service with a manifest" do
    before(:each) do
      @resource = Puppet::Type.type(:service).new(:name => "/system/myservice", :ensure => :running, :enable => :true, :manifest => "/tmp/myservice.xml")
      @provider = described_class.new(@resource)
      $CHILD_STATUS.stubs(:exitstatus).returns(1)
    end

    it "should import the manifest if service is missing" do
      @provider.stubs(:complete_service?).returns(true)
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

  context "when stopping" do
    it "should execute external command 'svcadm disable /system/myservice'" do
      @provider.expects(:texecute).with(:stop, ["/usr/sbin/svcadm", :disable, '-s', "/system/myservice"], true)
      @provider.expects(:wait).with('offline', 'disabled', 'uninitialized')
      @provider.stop
    end

    it "should error if timeout occurs while stopping the service" do
      @provider.expects(:texecute).with(:stop, ["/usr/sbin/svcadm", :disable, '-s', "/system/myservice"], true)
      Timeout.expects(:timeout).with(60).raises(Timeout::Error)
      expect { @provider.stop }.to raise_error Puppet::Error, ('Timed out waiting for /system/myservice to transition states')
    end
  end

  context "when restarting" do
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

  describe '#service_fmri' do
    it 'raises a Puppet::Error if the service resource matches multiple FMRIs' do
      @provider.stubs(:svcs).with('-l', @provider.resource[:name]).returns(File.read(my_fixture('svcs_multiple_fmris.out')))

      expect { @provider.service_fmri }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)
        expect(error.message).to match(@provider.resource[:name])
        expect(error.message).to match('multiple')

        matched_fmris = ["svc:/application/tstapp:one", "svc:/application/tstapp:two"]
        expect(error.message).to match(matched_fmris.join(', '))
      end
    end

    it 'raises a Puppet:ExecutionFailure if svcs fails' do
      @provider.stubs(:svcs).with('-l', @provider.resource[:name]).raises(
        Puppet::ExecutionFailure, 'svcs failed!'
      )

      expect { @provider.service_fmri }.to raise_error do |error|
        expect(error).to be_a(Puppet::ExecutionFailure)
        expect(error.message).to match('svcs failed!')
      end
    end

    it "returns the service resource's fmri and memoizes it" do
      @provider.stubs(:svcs).with('-l', @provider.resource[:name]).returns(File.read(my_fixture('svcs_fmri.out')))

      expected_fmri = 'svc:/application/tstapp:default'

      expect(@provider.service_fmri).to eql(expected_fmri)
      expect(@provider.instance_variable_get(:@fmri)).to eql(expected_fmri)
    end
  end

  describe '#complete_service?' do
    let(:fmri) { 'service_fmri' }

    before(:each) do
      @provider.stubs(:service_fmri).returns(fmri)
    end

    it 'should raise a Puppet::Error if it is called on an older Solaris machine' do
      Facter.stubs(:value).with(:operatingsystemrelease).returns('10.0')

      expect { @provider.complete_service? }.to raise_error(Puppet::Error)
    end

    it 'should return false for an incomplete service' do
      @provider.stubs(:svccfg).with('-s', fmri, 'listprop', 'general/complete').returns("")
      expect(@provider.complete_service?).to be false
    end

    it 'should return true for a complete service' do
      @provider.stubs(:svccfg)
        .with('-s', fmri, 'listprop', 'general/complete')
        .returns("general/complete astring")

      expect(@provider.complete_service?).to be true
    end
  end
end
