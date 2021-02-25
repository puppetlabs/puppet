require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Smf',
         unless: Puppet::Util::Platform.windows? || Puppet::Util::Platform.jruby? do
  let(:provider_class) { Puppet::Type.type(:service).provider(:smf) }

  def set_resource_params(params = {})
    params.each do |param, value|
      if value.nil?
        @provider.resource.delete(param) if @provider.resource[param]
      else
        @provider.resource[param] = value
      end
    end
  end

  before(:each) do
    # Create a mock resource
    @resource = Puppet::Type.type(:service).new(
      :name => "/system/myservice", :ensure => :running, :enable => :true)
    @provider = provider_class.new(@resource)

    allow(FileTest).to receive(:file?).with('/usr/sbin/svcadm').and_return(true)
    allow(FileTest).to receive(:executable?).with('/usr/sbin/svcadm').and_return(true)
    allow(FileTest).to receive(:file?).with('/usr/bin/svcs').and_return(true)
    allow(FileTest).to receive(:executable?).with('/usr/bin/svcs').and_return(true)
    allow(Facter).to receive(:value).with('os.name').and_return('Solaris')
    allow(Facter).to receive(:value).with('os.family').and_return('Solaris')
    allow(Facter).to receive(:value).with('os.release.full').and_return('11.2')
  end
  context ".instances" do
    it "should have an instances method" do
      expect(provider_class).to respond_to :instances
    end

    it "should get a list of services (excluding legacy)" do
      expect(provider_class).to receive(:svcs).with('-H', '-o', 'state,fmri').and_return(File.read(my_fixture('svcs_instances.out')))
      instances = provider_class.instances.map { |p| {:name => p.get(:name), :ensure => p.get(:ensure)} }
      # we dont manage legacy
      expect(instances.size).to eq(3)
      expect(instances[0]).to eq({:name => 'svc:/system/svc/restarter:default', :ensure => :running })
      expect(instances[1]).to eq({:name => 'svc:/network/cswrsyncd:default', :ensure => :maintenance })
      expect(instances[2]).to eq({:name => 'svc:/network/dns/client:default', :ensure => :degraded })
    end
  end

  describe '#service_exists?' do
    it 'returns true if the service exists' do
      expect(@provider).to receive(:service_fmri)
      expect(@provider.service_exists?).to be(true)
    end

    it 'returns false if the service does not exist' do
      expect(@provider).to receive(:service_fmri).and_raise(
        Puppet::ExecutionFailure, 'svcs failed!'
      )

      expect(@provider.service_exists?).to be(false)
    end
  end

  describe '#setup_service' do
    it 'noops if the service resource does not have the manifest parameter passed-in' do
      expect(@provider).not_to receive(:svccfg)

      set_resource_params({ :manifest => nil })
      @provider.setup_service
    end

    context 'when the service resource has a manifest parameter passed-in' do
      let(:manifest) { 'foo' }
      before(:each) { set_resource_params({ :manifest => manifest }) }

      it 'noops if the service resource already exists' do
        expect(@provider).not_to receive(:svccfg)

        expect(@provider).to receive(:service_exists?).and_return(true)
        @provider.setup_service
      end

      it "imports the service resource's manifest" do
        expect(@provider).to receive(:service_exists?).and_return(false)

        expect(@provider).to receive(:svccfg).with(:import, manifest)
        @provider.setup_service
      end

      it 'raises a Puppet::Error if SMF fails to import the manifest' do
        expect(@provider).to receive(:service_exists?).and_return(false)

        failure_reason = 'svccfg failed!'
        expect(@provider).to receive(:svccfg).with(:import, manifest).and_raise(Puppet::ExecutionFailure, failure_reason)
        expect { @provider.setup_service }.to raise_error do |error|
          expect(error).to be_a(Puppet::Error)
          expect(error.message).to match(failure_reason)
        end
      end
    end
  end

  describe '#service_fmri' do
    it 'returns the memoized the fmri if it exists' do
      @provider.instance_variable_set(:@fmri, 'resource_fmri')
      expect(@provider.service_fmri).to eql('resource_fmri')
    end

    it 'raises a Puppet::Error if the service resource matches multiple FMRIs' do
      expect(@provider).to receive(:svcs).with('-l', @provider.resource[:name]).and_return(File.read(my_fixture('svcs_multiple_fmris.out')))

      expect { @provider.service_fmri }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)
        expect(error.message).to match(@provider.resource[:name])
        expect(error.message).to match('multiple')

        matched_fmris = ["svc:/application/tstapp:one", "svc:/application/tstapp:two"]
        expect(error.message).to match(matched_fmris.join(', '))
      end
    end

    it 'raises a Puppet:ExecutionFailure if svcs fails' do
      expect(@provider).to receive(:svcs).with('-l', @provider.resource[:name]).and_raise(
        Puppet::ExecutionFailure, 'svcs failed!'
      )

      expect { @provider.service_fmri }.to raise_error do |error|
        expect(error).to be_a(Puppet::ExecutionFailure)
        expect(error.message).to match('svcs failed!')
      end
    end

    it "returns the service resource's fmri and memoizes it" do
      expect(@provider).to receive(:svcs).with('-l', @provider.resource[:name]).and_return(File.read(my_fixture('svcs_fmri.out')))

      expected_fmri = 'svc:/application/tstapp:default'

      expect(@provider.service_fmri).to eql(expected_fmri)
      expect(@provider.instance_variable_get(:@fmri)).to eql(expected_fmri)
    end
  end

  describe '#enabled?' do
    let(:fmri) { 'resource_fmri' }
    before(:each) do
      allow(@provider).to receive(:service_fmri).and_return(fmri)
    end

    it 'returns :true if the service is enabled' do
      expect(@provider).to receive(:svccfg).with('-s', fmri, 'listprop', 'general/enabled').and_return(
        'general/enabled boolean  true'
      )

      expect(@provider.enabled?).to be(:true)
    end

    it 'return :false if the service is not enabled' do
      expect(@provider).to receive(:svccfg).with('-s', fmri, 'listprop', 'general/enabled').and_return(
        'general/enabled boolean  false'
      )

      expect(@provider.enabled?).to be(:false)
    end

    it 'returns :false if the service does not exist' do
      expect(@provider).to receive(:service_exists?).and_return(false)
      expect(@provider.enabled?).to be(:false)
    end
  end

  describe '#restartcmd' do
    let(:fmri) { 'resource_fmri' }
    before(:each) do
      allow(@provider).to receive(:service_fmri).and_return(fmri)
    end

    it 'returns the right command for restarting the service for Solaris versions newer than 11.2' do
      expect(Facter).to receive(:value).with('os.release.full').and_return('11.3')

      expect(@provider.restartcmd).to eql([@provider.command(:adm), :restart, '-s', fmri])
    end

    it 'returns the right command for restarting the service on Solaris 11.2' do
      expect(Facter).to receive(:value).with('os.release.full').and_return('11.2')

      expect(@provider.restartcmd).to eql([@provider.command(:adm), :restart, '-s', fmri])
    end

    it 'returns the right command for restarting the service for Solaris versions older than Solaris 11.2' do
      expect(Facter).to receive(:value).with('os.release.full').and_return('10.3')

      expect(@provider.restartcmd).to eql([@provider.command(:adm), :restart, fmri])
    end
  end

  describe '#service_states' do
    let(:fmri) { 'resource_fmri' }
    before(:each) do
      allow(@provider).to receive(:service_fmri).and_return(fmri)
    end

    it 'returns the current and next states of the service' do
      expect(@provider).to receive(:svcs).with('-H', '-o', 'state,nstate', fmri).and_return(
        'online         disabled'
      )

      expect(@provider.service_states).to eql({ :current => 'online', :next => 'disabled' })
    end

    it "returns nil for the next state if svcs marks it as '-'" do
      expect(@provider).to receive(:svcs).with('-H', '-o', 'state,nstate', fmri).and_return(
        'online         -'
      )

      expect(@provider.service_states).to eql({ :current => 'online', :next => nil })
    end
  end

  describe '#wait' do
    # TODO: Document this method!
    def transition_service(from, to, tries)
      intermediate_returns = [{ :current => from, :next => to }] * (tries - 1)
      final_return = { :current => to, :next => nil }

      allow(@provider).to receive(:service_states).and_return(*intermediate_returns.push(final_return))
    end

    before(:each) do
      allow(Timeout).to receive(:timeout).and_yield
      allow(Kernel).to receive(:sleep)
    end

    it 'waits for the service to enter the desired state' do
      transition_service('online', 'disabled', 1)
      @provider.wait('offline', 'disabled', 'uninitialized')
    end

    it 'times out and raises a Puppet::Error after sixty seconds' do
      expect(Timeout).to receive(:timeout).with(60).and_raise(Timeout::Error, 'method timed out!')

      expect { @provider.wait('online') }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)
        expect(error.message).to match(@provider.resource[:name])
      end
    end

    it 'sleeps a bit before querying the service state' do
      transition_service('disabled', 'online', 10)
      expect(Kernel).to receive(:sleep).with(1).exactly(9).times

      @provider.wait('online')
    end
  end

  describe '#restart' do
    let(:fmri) { 'resource_fmri' }

    before(:each) do
      allow(@provider).to receive(:service_fmri).and_return(fmri)
      allow(@provider).to receive(:texecute)
      allow(@provider).to receive(:wait)
    end

    it 'should restart the service' do
      expect(@provider).to receive(:texecute)
      @provider.restart
    end

    it 'should wait for the service to restart' do
      expect(@provider).to receive(:wait).with('online')
      @provider.restart
    end
  end

  describe '#status' do
    let(:states) do
      {
        :current => 'online',
        :next    => nil
      }
    end

    before(:each) do
      allow(@provider).to receive(:service_states).and_return(states)

      allow(Facter).to receive(:value).with('os.release.full').and_return('10.3')
    end

    it "should run the status command if it's passed in" do
      set_resource_params({ :status => 'status_cmd' })
      expect(@provider).to receive(:ucommand).with(:status, false) do |_, _|
        expect($CHILD_STATUS).to receive(:exitstatus).and_return(0)
      end
      expect(@provider).not_to receive(:service_states)

      expect(@provider.status).to eql(:running)
    end

    shared_examples 'returns the right status' do |svcs_state, expected_state|
      it "returns '#{expected_state}' if the svcs state is '#{svcs_state}'" do

        states[:current] = svcs_state
        expect(@provider.status).to eql(expected_state)
      end
    end

    include_examples 'returns the right status', 'online', :running
    include_examples 'returns the right status', 'offline', :stopped
    include_examples 'returns the right status', 'disabled', :stopped
    include_examples 'returns the right status', 'uninitialized', :stopped
    include_examples 'returns the right status', 'maintenance', :maintenance
    include_examples 'returns the right status', 'degraded', :degraded

    it "raises a Puppet::Error if the svcs state is 'legacy_run'" do
      states[:current] = 'legacy_run'
      expect { @provider.status }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)
        expect(error.message).to match('legacy')
      end
    end

    it "raises a Puppet::Error if the svcs state is unmanageable" do
      states[:current] = 'unmanageable state'
      expect { @provider.status }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)
        expect(error.message).to match(states[:current])
      end
    end

    it "returns 'stopped' if the service does not exist" do
      expect(@provider).to receive(:service_states).and_raise(Puppet::ExecutionFailure, 'service does not exist!')
      expect(@provider.status).to eql(:stopped)
    end

    it "uses the current state for comparison if the next state is not provided" do
      states[:next] = 'disabled'
      expect(@provider.status).to eql(:stopped)
    end

    it "should return stopped for an incomplete service on Solaris 11" do
      allow(Facter).to receive(:value).with('os.release.full').and_return('11.3')
      allow(@provider).to receive(:complete_service?).and_return(false)
      expect(@provider.status).to eq(:stopped)
    end
  end

  describe '#maybe_clear_service_then_svcadm' do
    let(:fmri) { 'resource_fmri' }
    before(:each) do
      allow(@provider).to receive(:service_fmri).and_return(fmri)
    end

    it 'applies the svcadm subcommand with the given flags' do
      expect(@provider).to receive(:adm).with('enable', '-rst', fmri)
      @provider.maybe_clear_service_then_svcadm(:stopped, 'enable', '-rst')
    end

    [:maintenance, :degraded].each do |status|
      it "clears the service before applying the svcadm subcommand if the service status is #{status}" do
        expect(@provider).to receive(:adm).with('clear', fmri)
        expect(@provider).to receive(:adm).with('enable', '-rst', fmri)

        @provider.maybe_clear_service_then_svcadm(status, 'enable', '-rst')
      end
    end
  end

  describe '#flush' do
    def mark_property_for_syncing(property, value)
      properties_to_sync = @provider.instance_variable_get(:@properties_to_sync)
      properties_to_sync[property] = value
    end

    it 'should noop if enable and ensure do not need to be syncd' do
      expect(@provider).not_to receive(:setup_service)
      @provider.flush
    end

    context 'enable or ensure need to be syncd' do
      let(:stopped_states) do
        ['offline', 'disabled', 'uninitialized']
      end

      let(:fmri) { 'resource_fmri' }
      let(:mock_status) { :maintenance }
      before(:each) do
        allow(@provider).to receive(:setup_service)
        allow(@provider).to receive(:service_fmri).and_return(fmri)

        # We will update this mock on a per-test basis.
        allow(@provider).to receive(:status).and_return(mock_status)
        allow(@provider).to receive(:wait)
      end

      context 'only ensure needs to be syncd' do
        it 'stops the service if ensure == stopped' do
          mark_property_for_syncing(:ensure, :stopped)

          expect(@provider).to receive(:maybe_clear_service_then_svcadm).with(mock_status, 'disable', '-st')
          expect(@provider).to receive(:wait).with(*stopped_states)

          @provider.flush
        end

        it 'starts the service if ensure == running' do
          mark_property_for_syncing(:ensure, :running)

          expect(@provider).to receive(:maybe_clear_service_then_svcadm).with(mock_status, 'enable', '-rst')
          expect(@provider).to receive(:wait).with('online')

          @provider.flush
        end
      end

      context 'enable needs to be syncd' do
        before(:each) do
          # We will stub this value out later, this default is useful
          # for the final state tests.
          mark_property_for_syncing(:enable, true)
        end

        it 'enables the service' do
          mark_property_for_syncing(:enable, true)

          expect(@provider).to receive(:maybe_clear_service_then_svcadm).with(mock_status, 'enable', '-rs')

          expect(@provider).to receive(:adm).with('mark', '-I', 'maintenance', fmri)

          @provider.flush
        end

        it 'disables the service' do
          mark_property_for_syncing(:enable, false)

          expect(@provider).to receive(:maybe_clear_service_then_svcadm).with(mock_status, 'disable', '-s')

          expect(@provider).to receive(:adm).with('mark', '-I', 'maintenance', fmri)

          @provider.flush
        end

        context 'when the final service state is running' do
          before(:each) do
            allow(@provider).to receive(:status).and_return(:running)
          end

          it 'starts the service if enable was false' do
            mark_property_for_syncing(:enable, false)

            expect(@provider).to receive(:adm).with('disable', '-s', fmri)
            expect(@provider).to receive(:adm).with('enable', '-rst', fmri)
            expect(@provider).to receive(:wait).with('online')

            @provider.flush
          end

          it 'waits for the service to start if enable was true' do
            mark_property_for_syncing(:enable, true)

            expect(@provider).to receive(:adm).with('enable', '-rs', fmri)
            expect(@provider).to receive(:wait).with('online')

            @provider.flush
          end
        end

        context 'when the final service state is stopped' do
          before(:each) do
            allow(@provider).to receive(:status).and_return(:stopped)
          end

          it 'stops the service if enable was true' do
            mark_property_for_syncing(:enable, true)

            expect(@provider).to receive(:adm).with('enable', '-rs', fmri)
            expect(@provider).to receive(:adm).with('disable', '-st', fmri)
            expect(@provider).to receive(:wait).with(*stopped_states)

            @provider.flush
          end

          it 'waits for the service to stop if enable was false' do
            mark_property_for_syncing(:enable, false)

            expect(@provider).to_not receive(:adm).with('disable', '-st', fmri)
            expect(@provider).to receive(:wait).with(*stopped_states)

            @provider.flush
          end
        end

        it 'marks the service as being under maintenance if the final state is maintenance' do
          expect(@provider).to receive(:status).and_return(:maintenance)

          expect(@provider).to receive(:adm).with('clear', fmri)
          expect(@provider).to receive(:adm).with('enable', '-rs', fmri)

          expect(@provider).to receive(:adm).with('mark', '-I', 'maintenance', fmri)
          expect(@provider).to receive(:wait).with('maintenance')

          @provider.flush
        end

        it 'uses the ensure value as the final state if ensure also needs to be syncd' do
          mark_property_for_syncing(:ensure, :running)
          expect(@provider).to receive(:status).and_return(:stopped)

          expect(@provider).to receive(:adm).with('enable', '-rs', fmri)
          expect(@provider).to receive(:wait).with('online')

          @provider.flush
        end

        it 'marks the final state of a degraded service as running' do
          expect(@provider).to receive(:status).and_return(:degraded)

          expect(@provider).to receive(:adm).with('clear', fmri)
          expect(@provider).to receive(:adm).with('enable', '-rs', fmri)

          expect(@provider).to receive(:wait).with('online')

          @provider.flush
        end
      end
    end
  end
end
