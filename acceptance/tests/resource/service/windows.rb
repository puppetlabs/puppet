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

  new_user = "tempUser#{rand(999999).to_i}"
  fresh_user = "freshUser#{rand(999999).to_i}"

  fresh_user_manifest = <<-MANIFEST
    user { '#{fresh_user}':
      ensure => present,
      password => 'freshUserPassword#123',
      roles => 'SeServiceLogonRight'
    }

    service { '#{mock_service_nofail[:name]}':
      logonaccount => '#{fresh_user}',
      logonpassword => 'freshUserPassword#123',
      require => User['#{fresh_user}']
    }
  MANIFEST

  teardown do
    delete_service(agent, mock_service_nofail[:name])
    delete_service(agent, mock_service_long_start_stop[:name])
    on(agent, puppet("resource user #{new_user} ensure=absent"))
    on(agent, puppet("resource user #{fresh_user} ensure=absent"))
  end

  agents.each do |agent|
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

    step 'Verify that we can change logonaccount, for an already running service, using user created in the same manifest' do
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: 'LocalSystem')
      apply_manifest_on(agent, fresh_user_manifest, expect_changes: true)
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: fresh_user)
    end

    step 'Verify that running the same manifest twice causes no more changes' do
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: fresh_user)
      apply_manifest_on(agent, fresh_user_manifest, catch_changes: true)
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: fresh_user)
    end

    step 'Verify that we can change logonaccount, for an already running service, using SID' do
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: fresh_user)
      on(agent, puppet("resource service #{mock_service_nofail[:name]} logonaccount=S-1-5-19")) do |result|
        assert_match(/Service\[#{mock_service_nofail[:name]}\]\/logonaccount: logonaccount changed '.\\#{fresh_user}' to '#{Regexp.escape(local_service_locale_name)}'/, result.stdout)
        refute_match(/Transitioning the #{mock_service_nofail[:name]} service from SERVICE_RUNNING to SERVICE_STOPPED/, result.stdout, 
          "Expected no service restarts since ensure isn't being managed as 'running'.")
        refute_match(/Successfully started the #{mock_service_nofail[:name]} service/, result.stdout)
      end
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: local_service_locale_name)
    end

    step 'Verify that logonaccount noops if the logonaccount property is already synced' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], logonaccount: 'S-1-5-19'), catch_changes: true)
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: local_service_locale_name)
    end

    step 'Verify that setting logonaccount fails if input is invalid' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], logonaccount: 'InvalidUser'), :acceptable_exit_codes => [1]) do |result|
        assert_match(/"InvalidUser" is not a valid account/, result.stderr)
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
        refute_match(/Service\[#{mock_service_nofail[:name]}\]\/logonaccount: logonaccount changed/, result.stdout)
        refute_match(/Service\[#{mock_service_nofail[:name]}\]\/ensure: ensure changed/, result.stdout)
        refute_match(/Transitioning the #{mock_service_nofail[:name]} service from SERVICE_RUNNING to SERVICE_STOPPED/, result.stdout)
        refute_match(/Successfully started the #{mock_service_nofail[:name]} service/, result.stdout)
      end
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: 'LocalSystem')
    end

    step "Create a new user named #{new_user}" do
      on(agent, puppet("resource user #{new_user} ensure=present password=firstPassword#123")) do |result|
        assert_match(/User\[#{new_user}\]\/ensure: created/, result.stdout)
      end
    end

    step 'Verify that a user without the `Logon As A Service` right cannot be managed as the logonaccount of a service' do
      apply_manifest_on(agent, service_manifest(mock_service_long_start_stop[:name], logonaccount: new_user), :acceptable_exit_codes => [1]) do |result|
        assert_match(/#{new_user}" is missing the 'Log On As A Service' right./, result.stderr)
      end
    end

    step "Grant #{new_user} the `Logon As A Service` right" do
      on(agent, puppet("resource user #{new_user} roles='SeServiceLogonRight'")) do |result|
        assert_match(/User\[#{new_user}\]\/roles: roles changed  to 'SeServiceLogonRight'/, result.stdout)
      end
    end

    step 'Verify that setting logonpassword fails if input is invalid' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], logonaccount: new_user, logonpassword: 'wrongPass'), :acceptable_exit_codes => [1]) do |result|
        assert_match(/The given password is invalid for user '\.\\#{new_user}'/, result.stderr)
      end
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: 'LocalSystem')
    end

    step "Verify that #{new_user} can be set as logonaccount and service is still running" do
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: 'LocalSystem')
      on(agent, puppet("resource service #{mock_service_nofail[:name]} logonaccount=#{new_user} logonpassword=firstPassword#123 ensure=running --debug")) do |result|
        assert_match(/Service\[#{mock_service_nofail[:name]}\]\/logonaccount: logonaccount changed 'LocalSystem' to '.\\#{new_user}'/, result.stdout)
        assert_match(/Transitioning the #{mock_service_nofail[:name]} service from SERVICE_RUNNING to SERVICE_STOPPED/, result.stdout)
        assert_match(/Successfully started the #{mock_service_nofail[:name]} service/, result.stdout)
      end
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: new_user, State: 'Running')
    end

    step "Change password for #{new_user} and verify that service state isn't yet affected by this" do
      on(agent, puppet("resource user #{new_user} ensure=present password=secondPassword#123")) do |result|
        assert_match(/User\[#{new_user}\]\/password: changed \[redacted\] to \[redacted\]/, result.stdout)
      end
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: new_user, State: 'Running')
    end

    step 'Verify that setting logonpassword fails when using old password and service remains running' do
      apply_manifest_on(agent, service_manifest(mock_service_long_start_stop[:name], logonaccount: new_user, logonpassword: 'firstPassword#123'), :acceptable_exit_codes => [1]) do |result|
        assert_match(/The given password is invalid for user/, result.stderr)
      end
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: new_user, State: 'Running')
    end

    step 'Verify that setting the new logonpassword does not report any changes' do
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: new_user, State: 'Running')
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], logonaccount: new_user, logonpassword: 'secondPassword#123'), catch_changes: true)
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: new_user, State: 'Running')
    end

    step 'Verify that we can still stop the service' do
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: new_user, State: 'Running')
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], ensure: :stopped), expect_changes: true)
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: new_user, State: 'Stopped')
    end

    step 'Verify that the new logonpassword has actually been set by succesfully restarting the service' do
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: new_user, State: 'Stopped')
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], ensure: :running), expect_changes: true)
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: new_user, State: 'Running')
    end

    step "Deny #{new_user} the `Logon As A Service` right" do
      on(agent, puppet("resource user #{new_user} roles='SeDenyServiceLogonRight'")) do |result|
        assert_match(/User\[#{new_user}\]\/roles: roles changed SeServiceLogonRight to 'SeDenyServiceLogonRight,SeServiceLogonRight'/, result.stdout)
      end
    end

    step 'Verify that we can still stop the service' do
      assert_service_properties_on(agent, mock_service_nofail[:name], State: 'Running')
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], ensure: :stopped), expect_changes: true)
      assert_service_properties_on(agent, mock_service_nofail[:name], State: 'Stopped')
    end

    step 'Verify that the service cannot be started anymore because of the denied `Logon As A Service` right' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], ensure: :running), :acceptable_exit_codes => [4], catch_changes: true) do |result|
        assert_match(/Failed to start the service/, result.stderr)
      end
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: new_user, State: 'Stopped')
    end

    step 'Verify that a user with `Logon As A Service` right denied will raise error when managing it as logonaccount for a service' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], logonaccount: new_user), :acceptable_exit_codes => [1, 4]) do |result|
        assert_match(/#{new_user}\" has the 'Log On As A Service' right set to denied./, result.stderr)
      end
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: new_user, State: 'Stopped')
    end

    step "Grant back #{new_user} the `Logon As A Service` right for our subsequent tests" do
      on(agent, puppet("resource user #{new_user} roles='SeServiceLogonRight' role_membership=inclusive")) do |result|
        assert_match(/User\[#{new_user}\]\/roles: roles changed SeServiceLogonRight,SeDenyServiceLogonRight to 'SeServiceLogonRight'/, result.stdout)
      end
    end

    step 'Verify that ensure noops if the ensure property is already synced' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], ensure: :stopped), catch_changes: true)
      assert_service_properties_on(agent, mock_service_nofail[:name], State: 'Stopped')
    end

    step 'Verify that we can change logonaccount for a stopped service' do
      assert_service_properties_on(agent, mock_service_nofail[:name], State: 'Stopped', StartName: new_user)
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], logonaccount: local_service_locale_name), expect_changes: true)
      assert_service_properties_on(agent, mock_service_nofail[:name], State: 'Stopped', StartName: local_service_locale_name)
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

    step 'Disable the service and change logonaccount back to `LocalSystem` in preparation for our subsequent tests' do
      apply_manifest_on(agent, service_manifest(mock_service_nofail[:name], enable: false, logonaccount: 'LocalSystem'))
      assert_service_properties_on(agent, mock_service_nofail[:name], StartName: 'LocalSystem', StartMode: 'Disabled')
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
