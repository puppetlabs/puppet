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

  agents.each do |agent|
    mock_service = "mock_service_123"
    delete_service(agent, mock_service)

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
      manifest = service_manifest(mock_service, property)
      step "Verify #{operation} a non-existent service prints an error message but does not fail the run without detailed exit codes" do
        apply_manifest_on(agent, manifest) do |result|
          assert_match(/#{mock_service}/, result.stderr, "non-existent service should error when started, but received #{result.stderr}")
        end
      end

      step "Verify #{operation} a non-existent service with detailed exit codes correctly returns an error code" do
        apply_manifest_on(agent, manifest, :acceptable_exit_codes => [4])
      end
    end

    setup_service(agent, name: 'mock_service_123')

    step 'Verify that enable = false disables the service' do
      apply_manifest_on(agent, service_manifest(mock_service, enable: false))
      assert_service_properties_on(agent, mock_service, StartMode: 'Disabled')
    end

    step 'Verify that enable = manual indicates that the service can be started on demand' do
      apply_manifest_on(agent, service_manifest(mock_service, enable: :manual))
      assert_service_properties_on(agent, mock_service, StartMode: 'Manual')
    end

    step 'Verify that enable = true indicates that the service is started automatically upon reboot' do
      apply_manifest_on(agent, service_manifest(mock_service, enable: true))
      assert_service_properties_on(agent, mock_service, StartMode: 'Auto')
    end

    step 'Verify that enable noops if the enable property is already synced' do
      apply_manifest_on(agent, service_manifest(mock_service, enable: true), catch_changes: true)
      assert_service_properties_on(agent, mock_service, StartMode: 'Auto')
    end

    step 'Verify that we can start the service' do
      apply_manifest_on(agent, service_manifest(mock_service, ensure: :running))
      assert_service_properties_on(agent, mock_service, State: 'Running')
    end

    step 'Verify that we can stop the service' do
      apply_manifest_on(agent, service_manifest(mock_service, ensure: :stopped))
      assert_service_properties_on(agent, mock_service, State: 'Stopped')
    end

    step 'Verify that ensure noops if the ensure property is already synced' do
      apply_manifest_on(agent, service_manifest(mock_service, ensure: :stopped), catch_changes: true)
      assert_service_properties_on(agent, mock_service, State: 'Stopped')
    end

    step 'Verify that we can query the service with the RAL' do
      on(agent, puppet("resource service #{mock_service}")) do |result|
        assert_match( /enable => 'true'/, result.stdout, "Failed to query the service with the RAL on #{agent}")
      end
    end

    step 'Disable the service to prepare for our subsequent tests' do
      apply_manifest_on(agent, service_manifest(mock_service, enable: false))
      assert_service_properties_on(agent, mock_service, StartMode: 'Disabled')
    end

    step 'Verify that starting a disabled service fails if the enable property is not managed' do
      apply_manifest_on(agent, service_manifest(mock_service, ensure: :running)) do |result|
        assert_match(/#{mock_service}/, result.stderr, 'Windows service provider is able to start a disabled service without managing the enable property')
      end
    end

    step 'Verify that enable = false, ensure = running leaves the service disabled and in the running state' do
      apply_manifest_on(agent, service_manifest(mock_service, enable: false, ensure: :running))
      assert_service_properties_on(agent, mock_service, StartMode: 'Disabled', State: 'Running')
    end

    step 'Stop the service to prepare for our subsequent tests' do
      apply_manifest_on(agent, service_manifest(mock_service, ensure: :stopped))
      assert_service_properties_on(agent, mock_service, State: 'Stopped')
    end

    step 'Verify that enable = true, ensure = running leaves the service enabled and in the running state' do
      apply_manifest_on(agent, service_manifest(mock_service, enable: true, ensure: :running))
      assert_service_properties_on(agent, mock_service, StartMode: 'Auto', State: 'Running')
    end
  end
end
