test_name "Windows Service Provider" do
  confine :to, :platform => 'windows'

  tag 'audit:medium',
      'audit:acceptance'

  require 'puppet/acceptance/windows_utils'
  extend Puppet::Acceptance::WindowsUtils

  require 'puppet/acceptance/service_utils'
  extend Puppet::Acceptance::ServiceUtils

  def service_manifest(name, params)
    params_str = params.map do |param, value|
      value_str = value.to_s
      value_str = "\"#{value_str}\"" if value.is_a?(String)

      "  #{param} => #{value_str}"
    end.join(",\n")

    <<-MANIFEST
service { '#{name}':
  #{params_str}
}
MANIFEST
  end

  mock_service_nofail = {
    :name => "mock_service_nofail",
    :start_sleep => 0,
    :pause_sleep => 0,
    :continue_sleep => 0,
    :stop_sleep => 0,
  }

  # Since the default timeout for service operations is
  # 30 seconds, waiting for 40 should ensure that the service
  # operation will fail with a default timeout.
  mock_service_long_start_stop = {
    :name => "mock_service_long_start_stop",
    :start_sleep => 40,
    :pause_sleep => 0,
    :continue_sleep => 0,
    :stop_sleep => 40,
  }

  agents.each do |agent|
    delete_service(agent, mock_service_nofail[:name])

    run_nonexistent_service_tests(mock_service_nofail[:name])

    setup_service(agent, mock_service_nofail, 'MockService.cs')

    step 'Verify that enable = false disables the service' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], enable: false))
      assert_service_properties_on(agent, mock_service_nofail[:name], StartMode: 'Disabled')
    end

    step 'Verify that enable = manual indicates that the service can be started on demand' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], enable: :manual))
      assert_service_properties_on(agent, mock_service_nofail[:name], StartMode: 'Manual')
    end

    step 'Verify that enable = true indicates that the service is started automatically upon reboot' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], enable: true))
      assert_service_properties_on(agent, mock_service_nofail[:name], StartMode: 'Auto')
    end

    step 'Verify that enable noops if the enable property is already synced' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], enable: true), catch_changes: true)
      assert_service_properties_on(agent, mock_service_nofail[:name], StartMode: 'Auto')
    end

    step 'Verify that we can start the service' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], ensure: :running))
      assert_service_properties_on(agent, mock_service_nofail[:name], State: 'Running')
    end

    step 'Verify that we can stop the service' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], ensure: :stopped))
      assert_service_properties_on(agent, mock_service_nofail[:name], State: 'Stopped')
    end

    step 'Verify that ensure noops if the ensure property is already synced' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], ensure: :stopped), catch_changes: true)
      assert_service_properties_on(agent, mock_service_nofail[:name], State: 'Stopped')
    end

    step 'Verify that we can query the service with the RAL' do
      on(agent, puppet("resource service #{mock_service_nofail[:name]}")) do |result|
        assert_match( /enable => 'true'/, result.stdout, "Failed to query the service with the RAL on #{agent}")
      end
    end

    step 'Disable the service to prepare for our subsequent tests' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], enable: false))
      assert_service_properties_on(agent, mock_service_nofail[:name], StartMode: 'Disabled')
    end

    step 'Verify that starting a disabled service fails if the enable property is not managed' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], ensure: :running)) do |result|
        assert_match(/#{mock_service_nofail[:name]}/, result.stderr, 'Windows service provider is able to start a disabled service without managing the enable property')
      end
    end

    step 'Verify that enable = false, ensure = running leaves the service disabled and in the running state' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], enable: false, ensure: :running))
      assert_service_properties_on(agent, mock_service_nofail[:name], StartMode: 'Disabled', State: 'Running')
    end

    step 'Stop the service to prepare for our subsequent tests' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], ensure: :stopped))
      assert_service_properties_on(agent, mock_service_nofail[:name], State: 'Stopped')
    end

    step 'Verify that enable = true, ensure = running leaves the service enabled and in the running state' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], enable: true, ensure: :running))
      assert_service_properties_on(agent, mock_service_nofail[:name], StartMode: 'Auto', State: 'Running')
    end

    step 'Pause the service to prepare for the next test' do
      on(agent, powershell("Suspend-Service #{mock_service_nofail[:name]}"))
      assert_service_properties_on(agent, mock_service_nofail[:name], State: 'Paused')
    end

    step 'Verify that Puppet can resume a paused service' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], ensure: :running))
      assert_service_properties_on(agent, mock_service_nofail[:name], State: 'Running')
    end

    step 'Pause the service (again) to prepare for the next test' do
      on(agent, powershell("Suspend-Service #{mock_service_nofail[:name]}"))
      assert_service_properties_on(agent, mock_service_nofail[:name], State: 'Paused')
    end

    step 'Verify that Puppet can stop a paused service' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], ensure: :stopped))
      assert_service_properties_on(agent, mock_service_nofail[:name], State: 'Stopped')
    end

    # delete the service so it doesn't interfere with subsequent tests
    delete_service(agent, mock_service_nofail[:name])

    setup_service(agent, mock_service_long_start_stop, 'MockService.cs')

    step 'Verify that starting a service fails if the service does not start by the expiration of the wait hint' do
      apply_manifest_on(agent, service_manifest(mock_service_long_start_stop[:name], ensure: :running)) do |result|
        assert_match(/#{mock_service_long_start_stop[:name]}/, result.stderr, 'No progress made on service operation and dwWaitHint exceeded')
      end
    end

    # delete and recreate the service so it doesn't interfere with subsequent tests
    delete_service(agent, mock_service_long_start_stop[:name])
    setup_service(agent, mock_service_long_start_stop, 'MockService.cs')

    step 'Verify that starting a service works if the service has a long start and a long timeout' do
      apply_manifest_on(agent, service_manifest(mock_service_long_start_stop[:name], ensure: :running, timeout: 45))
      assert_service_properties_on(agent, mock_service_long_start_stop[:name], State: 'Running')
    end

    step 'Start the Service to prepare for subsequent test' do
      apply_manifest_on(agent, service_manifest(mock_service_long_start_stop[:name], enable: true, ensure: :running))
    end

    step 'Verify that stopping a service fails if the service does not stop by the expiration of the wait hint' do
      apply_manifest_on(agent, service_manifest(mock_service_long_start_stop[:name], ensure: :stopped)) do |result|
        assert_match(/#{mock_service_long_start_stop[:name]}/, result.stderr, 'No progress made on service operation and dwWaitHint exceeded')
      end
    end

    # delete the service so it doesn't interfere with subsequent tests
    delete_service(agent, mock_service_long_start_stop[:name])
  end
end
