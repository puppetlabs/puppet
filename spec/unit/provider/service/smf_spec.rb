require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Smf',
         unless: Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:smf) }

  before(:each) do
    # Create a mock resource
    @resource = Puppet::Type.type(:service).new(
      :name => "/system/myservice", :ensure => :running, :enable => :true)
    @provider = provider_class.new(@resource)

    allow(FileTest).to receive(:file?).with('/usr/sbin/svcadm').and_return(true)
    allow(FileTest).to receive(:executable?).with('/usr/sbin/svcadm').and_return(true)
    allow(FileTest).to receive(:file?).with('/usr/bin/svcs').and_return(true)
    allow(FileTest).to receive(:executable?).with('/usr/bin/svcs').and_return(true)
    allow(Facter).to receive(:value).with(:operatingsystem).and_return('Solaris')
    allow(Facter).to receive(:value).with(:osfamily).and_return('Solaris')
    allow(Facter).to receive(:value).with(:operatingsystemrelease).and_return('11.2')
  end

  context ".instances" do
    it "should have an instances method" do
      expect(provider_class).to respond_to :instances
    end

    it "should get a list of services (excluding legacy)" do
      expect(provider_class).to receive(:svcs).with('-H', '-o', 'state,fmri').and_return(File.read(my_fixture('svcs.out')))
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
    before(:each) do
      allow(@provider).to receive(:complete_service?).and_return(true)
    end

    it "should call the external command 'svcs /system/myservice' once" do
      expect(@provider).to receive(:svcs).with('-H', '-o', 'state,nstate', "/system/myservice").and_return("online\t-")
      @provider.status
    end

    it "should return stopped if svcs can't find the service" do
      allow(@provider).to receive(:svcs).and_raise(Puppet::ExecutionFailure.new("no svc found"))
      expect(@provider.status).to eq(:stopped)
    end

    it "should return stopped for an incomplete service on Solaris 11" do
      allow(Facter).to receive(:value).with(:operatingsystemrelease).and_return('11.3')
      allow(@provider).to receive(:complete_service?).and_return(false)
      expect(@provider.status).to eq(:stopped)
    end

    it "should return running if online in svcs output" do
      allow(@provider).to receive(:svcs).and_return("online\t-")
      expect(@provider.status).to eq(:running)
    end

    it "should return stopped if disabled in svcs output" do
      allow(@provider).to receive(:svcs).and_return("disabled\t-")
      expect(@provider.status).to eq(:stopped)
    end

    it "should return maintenance if in maintenance in svcs output" do
      allow(@provider).to receive(:svcs).and_return("maintenance\t-")
      expect(@provider.status).to eq(:maintenance)
    end

    it "should return degraded if in degraded in svcs output" do
      allow(@provider).to receive(:svcs).and_return("degraded\t-")
      expect(@provider.status).to eq(:degraded)
    end

    it "should return target state if transitioning in svcs output" do
      allow(@provider).to receive(:svcs).and_return("online\tdisabled")
      expect(@provider.status).to eq(:stopped)
    end

    it "should throw error if it's a legacy service in svcs output" do
      allow(@provider).to receive(:svcs).and_return("legacy_run\t-")
      expect { @provider.status }.to raise_error(Puppet::Error, "Cannot manage legacy services through SMF")
    end
  end

  context "when starting" do
    it "should enable the service if it is not enabled" do
      expect(@provider).to receive(:status).and_return(:stopped)
      expect(@provider).to receive(:texecute).with(:start, ['/usr/sbin/svcadm', :enable, '-rs', '/system/myservice'], true)
      expect(@provider).to receive(:wait).with('online')
      @provider.start
    end

    it "should always execute external command 'svcadm enable /system/myservice'" do
      expect(@provider).to receive(:status).and_return(:running)
      expect(@provider).to receive(:texecute).with(:start, ['/usr/sbin/svcadm', :enable, '-rs', '/system/myservice'], true)
      expect(@provider).to receive(:wait).with('online')
      @provider.start
    end

    it "should execute external command 'svcadm clear /system/myservice' if in maintenance" do
      allow(@provider).to receive(:status).and_return(:maintenance)
      expect(@provider).to receive(:texecute).with(:start, ["/usr/sbin/svcadm", :clear, "/system/myservice"], true)
      expect(@provider).to receive(:wait).with('online')
      @provider.start
    end

    it "should execute external command 'svcadm clear /system/myservice' if in degraded" do
      allow(@provider).to receive(:status).and_return(:degraded)
      expect(@provider).to receive(:texecute).with(:start, ["/usr/sbin/svcadm", :clear, "/system/myservice"], true)
      expect(@provider).to receive(:wait).with('online')
      @provider.start
    end

    it "should error if timeout occurs while starting the service" do
      expect(@provider).to receive(:status).and_return(:stopped)
      expect(@provider).to receive(:texecute).with(:start, ["/usr/sbin/svcadm", :enable, '-rs', "/system/myservice"], true)
      expect(Timeout).to receive(:timeout).with(60).and_raise(Timeout::Error)
      expect { @provider.start }.to raise_error Puppet::Error, ('Timed out waiting for /system/myservice to transition states')
    end
  end

  context "when starting a service with a manifest" do
    before(:each) do
      @resource = Puppet::Type.type(:service).new(:name => "/system/myservice", :ensure => :running, :enable => :true, :manifest => "/tmp/myservice.xml")
      @provider = provider_class.new(@resource)
      allow($CHILD_STATUS).to receive(:exitstatus).and_return(1)
    end

    it "should import the manifest if service is missing" do
      allow(@provider).to receive(:complete_service?).and_return(true)
      expect(@provider).to receive(:svcs).with('-l', '/system/myservice').and_raise(Puppet::ExecutionFailure, "Exited 1")
      expect(@provider).to receive(:svccfg).with(:import, "/tmp/myservice.xml")
      expect(@provider).to receive(:texecute).with(:start, ["/usr/sbin/svcadm", :enable, '-rs', "/system/myservice"], true)
      expect(@provider).to receive(:wait).with('online')
      expect(@provider).to receive(:svcs).with('-H', '-o', 'state,nstate', "/system/myservice").and_return("online\t-")
      @provider.start
    end

    it "should handle failures if importing a manifest" do
      expect(@provider).to receive(:svcs).with('-l', '/system/myservice').and_raise(Puppet::ExecutionFailure, "Exited 1")
      expect(@provider).to receive(:svccfg).and_raise(Puppet::ExecutionFailure.new("can't svccfg import"))
      expect { @provider.start }.to raise_error(Puppet::Error, "Cannot config /system/myservice to enable it: can't svccfg import")
    end
  end

  context "when stopping" do
    it "should execute external command 'svcadm disable /system/myservice'" do
      expect(@provider).to receive(:texecute).with(:stop, ["/usr/sbin/svcadm", :disable, '-s', "/system/myservice"], true)
      expect(@provider).to receive(:wait).with('offline', 'disabled', 'uninitialized')
      @provider.stop
    end

    it "should error if timeout occurs while stopping the service" do
      expect(@provider).to receive(:texecute).with(:stop, ["/usr/sbin/svcadm", :disable, '-s', "/system/myservice"], true)
      expect(Timeout).to receive(:timeout).with(60).and_raise(Timeout::Error)
      expect { @provider.stop }.to raise_error Puppet::Error, ('Timed out waiting for /system/myservice to transition states')
    end
  end

  context "when restarting" do
    it "should error if timeout occurs while restarting the service" do
      expect(@provider).to receive(:texecute).with(:restart, ["/usr/sbin/svcadm", :restart, '-s', "/system/myservice"], true)
      expect(Timeout).to receive(:timeout).with(60).and_raise(Timeout::Error)
      expect { @provider.restart }.to raise_error Puppet::Error, ('Timed out waiting for /system/myservice to transition states')
    end

    context 'with :operatingsystemrelease == 10_u10' do
      it "should call 'svcadm restart /system/myservice'" do
        allow(Facter).to receive(:value).with(:operatingsystemrelease).and_return('10_u10')
        expect(@provider).to receive(:texecute).with(:restart, ["/usr/sbin/svcadm", :restart, "/system/myservice"], true)
        expect(@provider).to receive(:wait).with('online')
        @provider.restart
      end
    end

    context 'with :operatingsystemrelease == 11.2' do
      it "should call 'svcadm restart -s /system/myservice'" do
        allow(Facter).to receive(:value).with(:operatingsystemrelease).and_return('11.2')
        expect(@provider).to receive(:texecute).with(:restart, ["/usr/sbin/svcadm", :restart, '-s', "/system/myservice"], true)
        expect(@provider).to receive(:wait).with('online')
        @provider.restart
      end
    end

    context 'with :operatingsystemrelease > 11.2' do
      it "should call 'svcadm restart -s /system/myservice'" do
        allow(Facter).to receive(:value).with(:operatingsystemrelease).and_return('11.3')
        expect(@provider).to receive(:texecute).with(:restart, ["/usr/sbin/svcadm", :restart, '-s', "/system/myservice"], true)
        expect(@provider).to receive(:wait).with('online')
        @provider.restart
      end
    end
  end

  describe '#service_fmri' do
    it 'raises a Puppet::Error if the service resource matches multiple FMRIs' do
      allow(@provider).to receive(:svcs).with('-l', @provider.resource[:name]).and_return(File.read(my_fixture('svcs_multiple_fmris.out')))

      expect { @provider.service_fmri }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)
        expect(error.message).to match(@provider.resource[:name])
        expect(error.message).to match('multiple')

        matched_fmris = ["svc:/application/tstapp:one", "svc:/application/tstapp:two"]
        expect(error.message).to match(matched_fmris.join(', '))
      end
    end

    it 'raises a Puppet:ExecutionFailure if svcs fails' do
      allow(@provider).to receive(:svcs).with('-l', @provider.resource[:name]).and_raise(
        Puppet::ExecutionFailure, 'svcs failed!'
      )

      expect { @provider.service_fmri }.to raise_error do |error|
        expect(error).to be_a(Puppet::ExecutionFailure)
        expect(error.message).to match('svcs failed!')
      end
    end

    it "returns the service resource's fmri and memoizes it" do
      allow(@provider).to receive(:svcs).with('-l', @provider.resource[:name]).and_return(File.read(my_fixture('svcs_fmri.out')))

      expected_fmri = 'svc:/application/tstapp:default'

      expect(@provider.service_fmri).to eql(expected_fmri)
      expect(@provider.instance_variable_get(:@fmri)).to eql(expected_fmri)
    end
  end

  describe '#complete_service?' do
    let(:fmri) { 'service_fmri' }

    before(:each) do
      allow(@provider).to receive(:service_fmri).and_return(fmri)
    end

    it 'should raise a Puppet::Error if it is called on an older Solaris machine' do
      allow(Facter).to receive(:value).with(:operatingsystemrelease).and_return('10.0')

      expect { @provider.complete_service? }.to raise_error(Puppet::Error)
    end

    it 'should return false for an incomplete service' do
      allow(@provider).to receive(:svccfg).with('-s', fmri, 'listprop', 'general/complete').and_return("")
      expect(@provider.complete_service?).to be false
    end

    it 'should return true for a complete service' do
      allow(@provider).to receive(:svccfg)
        .with('-s', fmri, 'listprop', 'general/complete')
        .and_return("general/complete astring")

      expect(@provider.complete_service?).to be true
    end
  end
end
