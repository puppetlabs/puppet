#! /usr/bin/env ruby
#
# Unit testing for the SMF service Provider
#
require 'spec_helper'

describe 'Puppet::Type::Service::Provider::Smf',
    if: Puppet.features.posix? && !Puppet::Util::Platform.jruby? do
  let(:resource) do
    Puppet::Type.type(:service).new(
      {
        :name => "/system/myservice"
      }
    )
  end
  let(:provider_class) { Puppet::Type.type(:service).provider(:smf) }
  let(:provider) do
    obj = provider_class.new(resource)
    
    # Stub out the commands
    [ :adm, :svcs, :svccfg ].each do |command|
      obj.stubs(command)
    end

    obj
  end

  def set_resource_params(params = {})
    params.each do |param, value|
      if value.nil?
        provider.resource.delete(param) if provider.resource[param]
      else
        provider.resource[param] = value
      end
    end
  end

  describe '.instances' do
    it "should get a list of all available services (excluding legacy)" do
      provider_class.expects(:svcs).with('-H', '-o', 'state,fmri').returns File.read(my_fixture('svcs_instances.out'))

      # We have one legacy service in our svcs_instances fixture that we don't manage.
      expected_instances = [
        'svc:/system/svc/restarter:default',
        'svc:/network/cswrsyncd:default',
        'svc:/network/dns/client:default'
      ]

      expect(provider_class.instances.map(&:name)).to eql(expected_instances)
    end
  end

  describe '#service_exists?' do
    it 'returns true if the service exists' do
      provider.expects(:service_fmri)
      expect(provider.service_exists?).to be(true)
    end

    it 'returns false if the service does not exist' do
      provider.stubs(:service_fmri).raises(
        Puppet::ExecutionFailure, 'svcs failed!'
      )

      expect(provider.service_exists?).to be(false)
    end
  end

  describe '#setup_service' do
    it 'noops if the service resource does not have the manifest parameter passed-in' do
      provider.expects(:svccfg).never

      set_resource_params({ :manifest => nil })
      provider.setup_service
    end

    context 'when the service resource has a manifest parameter passed-in' do
      let(:manifest) { 'foo' }
      before(:each) { set_resource_params({ :manifest => manifest }) }

      it 'noops if the service resource already exists' do
        provider.expects(:svccfg).never
  
        provider.expects(:service_exists?).returns(true)
        provider.setup_service
      end

      it "imports the service resource's manifest" do
        provider.expects(:service_exists?).returns(false)

        provider.expects(:svccfg).with(:import, manifest)
        provider.setup_service
      end

      it 'raises a Puppet::Error if SMF fails to import the manifest' do
        provider.expects(:service_exists?).returns(false)

        failure_reason = 'svccfg failed!'
        provider.expects(:svccfg).with(:import, manifest).raises(Puppet::ExecutionFailure, failure_reason)
        expect { provider.setup_service }.to raise_error do |error|
          expect(error).to be_a(Puppet::Error)
          expect(error.message).to match(failure_reason)
        end
      end
    end
  end

  describe '#service_fmri' do
    it 'returns the memoized the fmri if it exists' do
      provider.instance_variable_set(:@fmri, 'resource_fmri')
      expect(provider.service_fmri).to eql('resource_fmri')
    end

    it 'raises a Puppet::Error if the service resource matches multiple FMRIs' do
      provider.stubs(:svcs).with('-l', provider.resource[:name]).returns(File.read(my_fixture('svcs_multiple_fmris.out')))

      expect { provider.service_fmri }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)
        expect(error.message).to match(provider.resource[:name])
        expect(error.message).to match('multiple')

        matched_fmris = ["svc:/application/tstapp:one", "svc:/application/tstapp:two"]
        expect(error.message).to match(matched_fmris.join(', '))
      end
    end

    it 'raises a Puppet:ExecutionFailure if svcs fails' do
      provider.stubs(:svcs).with('-l', provider.resource[:name]).raises(
        Puppet::ExecutionFailure, 'svcs failed!'
      )

      expect { provider.service_fmri }.to raise_error do |error|
        expect(error).to be_a(Puppet::ExecutionFailure)
        expect(error.message).to match('svcs failed!')
      end
    end

    it "returns the service resource's fmri and memoizes it" do
      provider.stubs(:svcs).with('-l', provider.resource[:name]).returns(File.read(my_fixture('svcs_fmri.out')))

      expected_fmri = 'svc:/application/tstapp:default'

      expect(provider.service_fmri).to eql(expected_fmri)
      expect(provider.instance_variable_get(:@fmri)).to eql(expected_fmri)
    end
  end

  describe '#enabled?' do
    let(:fmri) { 'resource_fmri' }
    before(:each) do
      provider.stubs(:service_fmri).returns(fmri)
    end

    it 'returns :true if the service is enabled' do
      provider.expects(:svccfg).with('-s', fmri, 'listprop', 'general/enabled').returns(
        'general/enabled boolean  true'
      )

      expect(provider.enabled?).to be(:true)
    end

    it 'return :false if the service is not enabled' do
      provider.expects(:svccfg).with('-s', fmri, 'listprop', 'general/enabled').returns(
        'general/enabled boolean  false'
      )

      expect(provider.enabled?).to be(:false)
    end

    it 'returns :false if the service does not exist' do
      provider.expects(:service_exists?).returns(false)
      expect(provider.enabled?).to be(:false)
    end
  end

  describe '#restartcmd' do
    let(:fmri) { 'resource_fmri' }
    before(:each) do
      provider.stubs(:service_fmri).returns(fmri)
    end

    it 'returns the right command for restarting the service for Solaris versions newer than 11.2' do
      Facter.stubs(:value).with(:operatingsystemrelease).returns('11.3')

      expect(provider.restartcmd).to eql([provider.command(:adm), :restart, '-s', fmri])
    end

    it 'returns the right command for restarting the service on Solaris 11.2' do
      Facter.stubs(:value).with(:operatingsystemrelease).returns('11.3')

      expect(provider.restartcmd).to eql([provider.command(:adm), :restart, '-s', fmri])
    end

    it 'returns the right command for restarting the service for Solaris versions older than Solaris 11.2' do
      Facter.stubs(:value).with(:operatingsystemrelease).returns('10.2')

      expect(provider.restartcmd).to eql([provider.command(:adm), :restart, fmri])
    end
  end

  describe '#service_states' do
    let(:fmri) { 'resource_fmri' }
    before(:each) do
      provider.stubs(:service_fmri).returns(fmri)
    end

    it 'returns the current and next states of the service' do
      provider.expects(:svcs).with('-H', '-o', 'state,nstate', fmri).returns(
        'online         disabled'
      )

      expect(provider.service_states).to eql({ :current => 'online', :next => 'disabled' })
    end

    it "returns nil for the next state if svcs marks it as '-'" do
      provider.expects(:svcs).with('-H', '-o', 'state,nstate', fmri).returns(
        'online         -'
      )

      expect(provider.service_states).to eql({ :current => 'online', :next => nil })
    end
  end

  describe '#wait' do
    # TODO: Document this method!
    def transition_service(from, to, tries)
      intermediate_returns = [{ :current => from, :next => to }] * (tries - 1)
      final_return = { :current => to, :next => nil }
      
      provider.stubs(:service_states).returns(*intermediate_returns.push(final_return))
    end

    before(:each) do
      Timeout.stubs(:timeout).yields
      Kernel.stubs(:sleep)
    end

    it 'waits for the service to enter the desired state' do
      transition_service('online', 'disabled', 1)
      provider.wait('offline', 'disabled', 'uninitialized')
    end

    it 'times out and raises a Puppet::Error after sixty seconds' do
      Timeout.stubs(:timeout).with(60).raises(Timeout::Error, 'method timed out!')

      expect { provider.wait('online') }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)
        expect(error.message).to match(provider.resource[:name])
      end
    end

    it 'sleeps a bit before querying the service state' do
      transition_service('disabled', 'online', 10)
      Kernel.stubs(:sleep).with(1).times(9)

      provider.wait('online')
    end
  end

  describe '#restart' do
    let(:fmri) { 'resource_fmri' }

    before(:each) do
      provider.stubs(:service_fmri).returns(fmri)
      provider.stubs(:texecute)
      provider.stubs(:wait)
    end

    it 'should restart the service' do
      provider.expects(:texecute)
      provider.restart
    end

    it 'should wait for the service to restart' do
      provider.expects(:wait).with('online')
      provider.restart
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
      provider.stubs(:service_states).returns(states)
    end

    it "should run the status command if it's passed in" do
      set_resource_params({ :status => 'status_cmd' })
      provider.stubs(:ucommand).with(provider.resource[:status], false) do |_, _|
        $CHILD_STATUS.stubs(:exitstatus).returns(0)
      end
      provider.expects(:service_states).never

      expect(provider.status).to eql(:running)
    end

    shared_examples 'returns the right status' do |svcs_state, expected_state|
      it "returns '#{expected_state}' if the svcs state is '#{svcs_state}'" do
        states[:current] = svcs_state
        expect(provider.status).to eql(expected_state)
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
      expect { provider.status }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)
        expect(error.message).to match('legacy')
      end
    end

    it "raises a Puppet::Error if the svcs state is unmanageable" do
      states[:current] = 'unmanageable state'
      expect { provider.status }.to raise_error do |error|
        expect(error).to be_a(Puppet::Error)
        expect(error.message).to match(states[:current])
      end
    end

    it "returns 'stopped' if the service does not exist" do
      provider.stubs(:service_states).raises(Puppet::ExecutionFailure, 'service does not exist!')
      expect(provider.status).to eql(:stopped)
    end

    it "uses the current state for comparison if the next state is not provided" do
      states[:next] = 'disabled'
      expect(provider.status).to eql(:stopped)
    end
  end

  describe '#maybe_clear_service_then_svcadm' do
    let(:fmri) { 'resource_fmri' }
    before(:each) do
      provider.stubs(:service_fmri).returns(fmri)
    end

    it 'applies the svcadm subcommand with the given flags' do
      provider.expects(:adm).with('enable', '-rst', fmri)
      provider.maybe_clear_service_then_svcadm(:stopped, 'enable', '-rst')
    end

    [:maintenance, :degraded].each do |status|
      it "clears the service before applying the svcadm subcommand if the service status is #{status}" do
        provider.expects(:adm).with('clear', fmri)
        provider.expects(:adm).with('enable', '-rst', fmri)

        provider.maybe_clear_service_then_svcadm(status, 'enable', '-rst')
      end
    end
  end

  describe '#flush' do
    def mark_property_for_syncing(property, value)
      properties_to_sync = provider.instance_variable_get(:@properties_to_sync)
      properties_to_sync[property] = value
    end

    it 'should noop if enable and ensure do not need to be syncd' do
      provider.expects(:setup_service).never
      provider.flush
    end

    context 'enable or ensure need to be syncd' do
      let(:stopped_states) do
        ['offline', 'disabled', 'uninitialized']
      end

      let(:fmri) { 'resource_fmri' }
      let(:mock_status) { :maintenance }
      before(:each) do
        provider.expects(:setup_service)
        provider.stubs(:service_fmri).returns(fmri)

        # We will update this mock on a per-test basis.
        provider.stubs(:status).returns(mock_status)
        provider.stubs(:wait)
      end

      context 'only ensure needs to be syncd' do
        it 'stops the service if ensure == stopped' do
          mark_property_for_syncing(:ensure, :stopped)

          provider.expects(:maybe_clear_service_then_svcadm).with(mock_status, 'disable', '-st')
          provider.expects(:wait).with(*stopped_states)

          provider.flush
        end

        it 'starts the service if ensure == running' do
          mark_property_for_syncing(:ensure, :running)

          provider.expects(:maybe_clear_service_then_svcadm).with(mock_status, 'enable', '-rst')
          provider.expects(:wait).with('online')

          provider.flush
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

          provider.expects(:maybe_clear_service_then_svcadm).with(mock_status, 'enable', '-rs')

          provider.flush
        end

        it 'disables the service' do
          mark_property_for_syncing(:enable, false)

          provider.expects(:maybe_clear_service_then_svcadm).with(mock_status, 'disable', '-s')

          provider.flush
        end

        context 'when the final service state is running' do
          before(:each) do
            provider.stubs(:status).returns(:running)
          end

          it 'starts the service if enable was false' do
            mark_property_for_syncing(:enable, false)

            provider.expects(:adm).with('enable', '-rst', fmri)
            provider.expects(:wait).with('online')

            provider.flush
          end

          it 'waits for the service to start if enable was true' do
            mark_property_for_syncing(:enable, true)

            provider.expects(:adm).with('enable', '-rst', fmri).never
            provider.expects(:wait).with('online')

            provider.flush
          end
        end

        context 'when the final service state is stopped' do
          before(:each) do
            provider.stubs(:status).returns(:stopped)
          end

          it 'stops the service if enable was true' do
            mark_property_for_syncing(:enable, true)

            provider.expects(:adm).with('disable', '-st', fmri)
            provider.expects(:wait).with(*stopped_states)

            provider.flush
          end

          it 'waits for the service to stop if enable was false' do
            mark_property_for_syncing(:enable, false)

            provider.expects(:adm).with('disable', '-st', fmri).never
            provider.expects(:wait).with(*stopped_states)

            provider.flush
          end
        end

        it 'marks the service as being under maintenance if the final state is maintenance' do
          provider.stubs(:status).returns(:maintenance)

          provider.expects(:adm).with('mark', '-I', 'maintenance', fmri)
          provider.expects(:wait).with('maintenance')

          provider.flush
        end

        it 'uses the ensure value as the final state if ensure also needs to be syncd' do
          mark_property_for_syncing(:ensure, :running)
          provider.stubs(:status).returns(:stopped)

          provider.expects(:wait).with('online')

          provider.flush
        end

        it 'marks the final state of a degraded service as running' do
          provider.stubs(:status).returns(:degraded)

          provider.expects(:wait).with('online')

          provider.flush
        end
      end
    end
  end
end
