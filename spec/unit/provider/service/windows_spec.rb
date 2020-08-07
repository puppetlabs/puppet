require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Windows',
    :if => Puppet::Util::Platform.windows? && !Puppet::Util::Platform.jruby? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:windows) }
  let(:name)     { 'nonexistentservice' }
  let(:resource) { Puppet::Type.type(:service).new(:name => name, :provider => :windows) }
  let(:provider) { resource.provider }
  let(:config)   { Struct::ServiceConfigInfo.new }
  let(:status)   { Struct::ServiceStatus.new }
  let(:service_util) { Puppet::Util::Windows::Service }
  let(:service_handle) { double() }

  before :each do
    # make sure we never actually execute anything (there are two execute methods)
    allow(provider.class).to receive(:execute)
    allow(provider).to receive(:execute)

    allow(service_util).to receive(:exists?).with(resource[:name]).and_return(true)
  end

  describe ".instances" do
    it "should enumerate all services" do
      list_of_services = {'snmptrap' => {}, 'svchost' => {}, 'sshd' => {}}
      expect(service_util).to receive(:services).and_return(list_of_services)

      expect(provider_class.instances.map(&:name)).to match_array(['snmptrap', 'svchost', 'sshd'])
    end
  end

  describe "#start" do
    before(:each) do
      allow(provider).to receive(:status).and_return(:stopped)
    end

    it "should resume a paused service" do
      allow(provider).to receive(:status).and_return(:paused)
      expect(service_util).to receive(:resume)
      provider.start
    end

    it "should start the service" do
      expect(service_util).to receive(:service_start_type).with(name).and_return(:SERVICE_AUTO_START)
      expect(service_util).to receive(:start)
      provider.start
    end

    context "when the service is disabled" do
      before :each do
        expect(service_util).to receive(:service_start_type).with(name).and_return(:SERVICE_DISABLED)
      end

      it "should refuse to start if not managing enable" do
        expect { provider.start }.to raise_error(Puppet::Error, /Will not start disabled service/)
      end

      it "should enable if managing enable and enable is true" do
        resource[:enable] = :true
        expect(service_util).to receive(:start)
        expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_AUTO_START})

        provider.start
      end

      it "should manual start if managing enable and enable is false" do
        resource[:enable] = :false
        expect(service_util).to receive(:start)
        expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_DEMAND_START})

        provider.start
      end
    end
  end

  describe "#stop" do
    it "should stop a running service" do
      expect(service_util).to receive(:stop)

      provider.stop
    end
  end

  describe "#status" do
    it "should report a nonexistent service as stopped" do
      allow(service_util).to receive(:exists?).with(resource[:name]).and_return(false)

      expect(provider.status).to eql(:stopped)
    end

    it "should report service as stopped when status cannot be retrieved" do
      allow(service_util).to receive(:exists?).with(resource[:name]).and_return(true)
      allow(service_util).to receive(:service_state).with(name).and_raise(Puppet::Error.new('Service query failed: The specified path is invalid.'))

      expect(Puppet).to receive(:warning).with("Status for service #{resource[:name]} could not be retrieved: Service query failed: The specified path is invalid.")
      expect(provider.status).to eql(:stopped)
    end

    [
      :SERVICE_PAUSED,
      :SERVICE_PAUSE_PENDING
    ].each do |state|
      it "should report a #{state} service as paused" do
        expect(service_util).to receive(:service_state).with(name).and_return(state)
        expect(provider.status).to eq(:paused)
      end
    end

    [
      :SERVICE_STOPPED,
      :SERVICE_STOP_PENDING
    ].each do |state|
      it "should report a #{state} service as stopped" do
        expect(service_util).to receive(:service_state).with(name).and_return(state)
        expect(provider.status).to eq(:stopped)
      end
    end

    [
      :SERVICE_RUNNING,
      :SERVICE_CONTINUE_PENDING,
      :SERVICE_START_PENDING,
    ].each do |state|
      it "should report a #{state} service as running" do
        expect(service_util).to receive(:service_state).with(name).and_return(state)

        expect(provider.status).to eq(:running)
      end
    end

    context 'when querying lmhosts', if: Puppet::Util::Platform.windows? do
      # This service should be ubiquitous across all supported Windows platforms
      let(:service) { Puppet::Type.type(:service).new(:name => 'lmhosts') }

      before :each do
        allow(service_util).to receive(:exists?).with(service.name).and_call_original
      end

      it "reports if the service is enabled" do
        expect([:true, :false, :manual]).to include(service.provider.enabled?)
      end

      it "reports on the service status" do
        expect(
          [
            :running,
            :'continue pending',
            :'pause pending',
            :paused,
            :running,
            :'start pending',
            :'stop pending',
            :stopped
          ]
        ).to include(service.provider.status)
      end
    end
  end

  describe "#restart" do
    it "should use the supplied restart command if specified" do
      resource[:restart] = 'c:/bin/foo'

      expect(provider).to receive(:execute).with(['c:/bin/foo'], :failonfail => true, :override_locale => false, :squelch => false, :combine => true)

      provider.restart
    end

    it "should restart the service" do
      expect(provider).to receive(:stop).ordered
      expect(provider).to receive(:start).ordered

      provider.restart
    end
  end

  describe "#enabled?" do
    it "should report a nonexistent service as false" do
      allow(service_util).to receive(:exists?).with(resource[:name]).and_return(false)

      expect(provider.enabled?).to eql(:false)
    end

    it "should report a service with a startup type of manual as manual" do
      expect(service_util).to receive(:service_start_type).with(name).and_return(:SERVICE_DEMAND_START)
      expect(provider.enabled?).to eq(:manual)
    end

    it "should report a service with a startup type of delayed as delayed" do
      expect(service_util).to receive(:service_start_type).with(name).and_return(:SERVICE_DELAYED_AUTO_START)
      expect(provider.enabled?).to eq(:delayed)
    end

    it "should report a service with a startup type of disabled as false" do
      expect(service_util).to receive(:service_start_type).with(name).and_return(:SERVICE_DISABLED)
      expect(provider.enabled?).to eq(:false)
    end

    # We need to guard this section explicitly since rspec will always
    # construct all examples, even if it isn't going to run them.
    if Puppet.features.microsoft_windows?
      [
        :SERVICE_AUTO_START,
        :SERVICE_BOOT_START,
        :SERVICE_SYSTEM_START
      ].each do |start_type|
        it "should report a service with a startup type of '#{start_type}' as true" do
          expect(service_util).to receive(:service_start_type).with(name).and_return(start_type)
          expect(provider.enabled?).to eq(:true)
        end
      end
    end
  end

  describe "#enable" do
    it "should set service start type to Service_Auto_Start when enabled" do
      expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_AUTO_START})
      provider.enable
    end

    it "raises an error if set_startup_configuration fails" do
      expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_AUTO_START}).and_raise(Puppet::Error.new('foobar'))

      expect {
        provider.enable
      }.to raise_error(Puppet::Error, /Cannot enable #{name}/)
    end
  end

  describe "#disable" do
    it "should set service start type to Service_Disabled when disabled" do
      expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_DISABLED})
      provider.disable
    end

    it "raises an error if set_startup_configuration fails" do
      expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_DISABLED}).and_raise(Puppet::Error.new('foobar'))

      expect {
        provider.disable
      }.to raise_error(Puppet::Error, /Cannot disable #{name}/)
    end
  end

  describe "#manual_start" do
    it "should set service start type to Service_Demand_Start (manual) when manual" do
      expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_DEMAND_START})
      provider.manual_start
    end

    it "raises an error if set_startup_configuration fails" do
      expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_DEMAND_START}).and_raise(Puppet::Error.new('foobar'))

      expect {
        provider.manual_start
      }.to raise_error(Puppet::Error, /Cannot enable #{name}/)
    end
  end

  describe "#delayed_start" do
    it "should set service start type to Service_Config_Delayed_Auto_Start (delayed) when delayed" do
      expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_AUTO_START, delayed: true})
      provider.delayed_start
    end

    it "raises an error if set_startup_configuration fails" do
      expect(service_util).to receive(:set_startup_configuration).with(name, options: {startup_type: :SERVICE_AUTO_START, delayed: true}).and_raise(Puppet::Error.new('foobar'))

      expect {
        provider.delayed_start
      }.to raise_error(Puppet::Error, /Cannot enable #{name}/)
    end
  end
end
