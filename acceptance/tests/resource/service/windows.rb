test_name "Windows Service Provider" do
  confine :to, :platform => 'windows'

  tag 'audit:medium',
      'audit:acceptance'

  require 'puppet/acceptance/windows_utils'
  extend Puppet::Acceptance::WindowsUtils

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

  # The wait hint we provide in MockService.cs is
  # 10 seconds, having the service sleep for 20
  # will supply the failure scenario on a failed
  # startup
  mock_service_startfail = {
    :name => "mock_service_startfail",
    :start_sleep => 20,
    :pause_sleep => 0,
    :continue_sleep => 0,
    :stop_sleep => 0,
  }
  # The wait hint we provide in MockService.cs is
  # 10 seconds, having the service sleep for 20
  # will supply the failure scenario on a failed
  # shutdown
  mock_service_stopfail = {
    :name => "mock_service_stopfail",
    :start_sleep => 0,
    :pause_sleep => 0,
    :continue_sleep => 0,
    :stop_sleep => 20,
  }

  agents.each do |agent|
    delete_service(agent, mock_service_nofail[:name])

    # TODO: Once non-existent service semantics have been properly enabled for
    # Windows, these tests + the AIX non-existent service tests should be moved
    # into a generic 'run_nonexistent_service_tests' routine. To make that move
    # easier, we've written these tests in a more generic style.
    #
    # NOTE: Currently, we only run a subset of the nonexistent service tests.
    {
      'enabling' => { enable: true },
      'starting' => { ensure: :running }
    }.each do |operation, property|
      manifest = service_manifest(mock_service_nofail[:name], property)
      step "Verify #{operation} a non-existent service prints an error message but does not fail the run without detailed exit codes" do
        apply_manifest_on(agent, manifest) do |result|
          assert_match(/#{mock_service_nofail[:name]}/, result.stderr, "non-existent service should error when started, but received #{result.stderr}")
        end
      end

      step "Verify #{operation} a non-existent service with detailed exit codes correctly returns an error code" do
        apply_manifest_on(agent, manifest, :acceptable_exit_codes => [4])
      end
    end

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

    # delete the service so it doesn't interfere with subsequent tests
    delete_service(agent, mock_service_nofail[:name])

    setup_service(agent, mock_service_startfail, 'MockService.cs')

    step 'Verify that starting a service fails if the service does not start by the expiration of the wait hint' do
      apply_manifest_on(agent, service_manifest(mock_service_startfail[:name], ensure: :running)) do |result|
        assert_match(/#{mock_service_startfail[:name]}/, result.stderr, 'No progress made on service operation and dwWaitHint exceeded')
      end
    end

    # delete the service so it doesn't interfere with subsequent tests
    delete_service(agent, mock_service_startfail[:name])

    setup_service(agent, mock_service_stopfail, 'MockService.cs')

    step 'Start the Service to prepare for subsequent test' do
      apply_manifest_on(agent, service_manifest(mock_service_stopfail[:name], enable: true, ensure: :running))
    end

    step 'Verify that stopping a service fails if the service does not stop by the expiration of the wait hint' do
      apply_manifest_on(agent, service_manifest(mock_service_stopfail[:name], ensure: :stopped)) do |result|
        assert_match(/#{mock_service_stopfail[:name]}/, result.stderr, 'No progress made on service operation and dwWaitHint exceeded')
      end
    end

    # delete the service so it doesn't interfere with subsequent tests
    delete_service(agent, mock_service_stopfail[:name])
  end
end
