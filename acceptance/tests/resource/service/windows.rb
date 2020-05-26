test_name "Windows Service Provider" do
  confine :to, :platform => 'windows'

  tag 'audit:high',
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

  teardown do
    delete_service(agent, mock_service_long_start_stop[:name])
  end

  agents.each do |agent|
    administrator_locale_name = agent['locale'] == 'fr' ? '.\Administrateur' : '.\Administrator'
    local_service_locale_name = agent['locale'] == 'fr' ? 'AUTORITE NT\SERVICE LOCAL' : 'NT AUTHORITY\LOCAL SERVICE'

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

    step 'Verify that enable = delayed indicates that the service start mode is correctly set' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], enable: :delayed))
      assert_service_startmode_delayed(agent, mock_service_nofail[:name])
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

    step 'Verify that we can change logonaccount, for an already running service, using SID' do
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: 'LocalSystem')
      on(agent, puppet("resource service #{mock_service_nofail[:name]} logonaccount=S-1-5-19")) do |result|
        assert_match(/Service\[#{mock_service_nofail[:name]}\]\/logonaccount: logonaccount changed 'LocalSystem' to '#{Regexp.escape(local_service_locale_name)}'/, result.stdout)
        assert_no_match(/Transitioning the #{mock_service_nofail[:name]} service from SERVICE_RUNNING to SERVICE_STOPPED/, result.stdout, 
          "Expected no service restarts since ensure isn't being managed as 'running'.")
        assert_no_match(/Successfully started the #{mock_service_nofail[:name]} service/, result.stdout)
      end
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: local_service_locale_name)
    end

    step 'Verify that logonaccount noops if the logonaccount property is already synced' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], logonaccount: 'S-1-5-19'), catch_changes: true)
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: local_service_locale_name)
    end

    step 'Verify that setting logonaccount fails if input is invalid' do
      apply_manifest_on(agent, service_manifest(mock_service_long_start_stop[:name], logonaccount: 'InvalidUser'), :acceptable_exit_codes => [1]) do |result|
        assert_match(/"InvalidUser" is not a valid account/, result.stderr)
      end
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: local_service_locale_name)
    end

    step 'Verify that setting logonpassword fails if input is invalid' do
      apply_manifest_on(agent, service_manifest(mock_service_long_start_stop[:name], logonaccount: administrator_locale_name, logonpassword: 'wrongPass'), :acceptable_exit_codes => [1]) do |result|
        assert_match(/The given password is invalid for user '#{Regexp.escape(administrator_locale_name)}'/, result.stderr)
      end
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: local_service_locale_name)
    end

    step 'Verify that the service restarts if it is already running, logonaccount is different from last run and ensure is set to running' do
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: local_service_locale_name)
      on(agent, puppet("resource service #{mock_service_nofail[:name]} logonaccount=LocalSystem ensure=running --debug")) do |result|
        assert_match(/Service\[#{mock_service_nofail[:name]}\]\/logonaccount: logonaccount changed '#{Regexp.escape(local_service_locale_name)}' to 'LocalSystem'/, result.stdout)
        assert_match(/Transitioning the #{mock_service_nofail[:name]} service from SERVICE_RUNNING to SERVICE_STOPPED/, result.stdout)
        assert_match(/Successfully started the #{mock_service_nofail[:name]} service/, result.stdout)
      end
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: 'LocalSystem')
    end

    step 'Verify that there are no restarts if logonaccount does not change, even though ensure is managed as running' do
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: 'LocalSystem')
      on(agent, puppet("resource service #{mock_service_nofail[:name]} logonaccount=LocalSystem ensure=running --debug")) do |result|
        assert_no_match(/Service\[#{mock_service_nofail[:name]}\]\/logonaccount: logonaccount changed/, result.stdout)
        assert_no_match(/Service\[#{mock_service_nofail[:name]}\]\/ensure: ensure changed/, result.stdout)
        assert_no_match(/Transitioning the #{mock_service_nofail[:name]} service from SERVICE_RUNNING to SERVICE_STOPPED/, result.stdout)
        assert_no_match(/Successfully started the #{mock_service_nofail[:name]} service/, result.stdout)
      end
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: 'LocalSystem')
    end

    step 'Verify that we can stop the service' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], ensure: :stopped))
      assert_service_properties_on(agent, mock_service_nofail[:name], State: 'Stopped')
    end

    step 'Verify that ensure noops if the ensure property is already synced' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], ensure: :stopped), catch_changes: true)
      assert_service_properties_on(agent, mock_service_nofail[:name], State: 'Stopped')
    end

    step 'Verify that we can change logonaccount for a stopped service' do
      assert_service_properties_on(agent, mock_service_nofail[:name], State: 'Stopped')
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: 'LocalSystem')
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], logonaccount: local_service_locale_name), expect_changes: true)
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: local_service_locale_name)
      assert_service_properties_on(agent, mock_service_nofail[:name], State: 'Stopped')
    end

    step 'Verify that logonaccount noops if the logonaccount property is already synced' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], logonaccount: local_service_locale_name), catch_changes: true)
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: local_service_locale_name)
    end

    step 'Verify that we can query the service with the RAL' do
      on(agent, puppet("resource service #{mock_service_nofail[:name]}")) do |result|
        assert_match( /enable\s+=>\s+'true'/, result.stdout, "Failed to query the service with the RAL on #{agent}")
      end
    end

    step 'Disable the service and change logonaccount to localsystem in preparation for our subsequent tests' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], enable: false, logonaccount: 'LocalSystem'))
      assert_service_properties_on(agent, mock_service_nofail[:name], StartMode: 'Disabled')
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: 'LocalSystem')
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
  end
end
