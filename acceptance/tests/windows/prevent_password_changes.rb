require 'date'

def random_username
  "pl#{rand(999999).to_i}"
end

def set_password_manifest(username)
  new_password = "Password-#{rand(999999).to_i}"[0..11]
  manifest = <<-MANIFEST
    user { '#{username}':
      ensure   => 'present',
      password => '#{new_password}'
    }
  MANIFEST
end

def check_password_on(host, username, password)
  script = <<-PS1
  Add-Type -AssemblyName System.DirectoryServices.AccountManagement
  $ctx = New-Object System.DirectoryServices.AccountManagement.PrincipalContext("machine", $env:COMPUTERNAME)
  $ctx.ValidateCredentials("#{username}", "#{password}")
  PS1
  execute_powershell_script_on(host, script) do |result|
    assert_match(/True/, result.stdout, "Expected password for user #{username} to be '#{password}', but it was not")
  end
end

old_password = '0ldP@ssword'

hosts.each do |host|
  test_name 'PUP-6569 Passwords are not reset for disabled accounts' do
    tag 'audit:low'
    confine :to, platform: 'windows'

    disabled_username = random_username

    step "Create a disabled user account" do
      on(host, "net user #{disabled_username} /active:no /add")
    end

    step "Try to change the disabled user account's password with puppet" do
      apply_manifest_on(host, set_password_manifest(disabled_username)) do |result|
        assert_match(/Warn.*disabled/i, result.stderr, "Missing warning when attempting to reset a disabled user account's password") unless host['locale'] == 'ja'
      end
    end

    step "Ensure the password wasn't changed" do
      check_password_on(host, disabled_username, old_password)
    end

    teardown do
      on(host, "net user #{disabled_username} /delete", accept_all_exit_codes: true)
    end
  end

  test_name 'PUP-6569 Passwords are not reset for expired accounts' do
    tag 'audit:low'
    confine :to, platform: 'windows'

    expired_username = random_username

    step "Create an expired user account" do
      on(host, "net user #{expired_username} /expires:#{(Date.today - 1).strftime('%m-%d-%Y')} /add")
    end

    step "Try to change the expired user's password with puppet" do
      apply_manifest_on(host, set_password_manifest(expired_username)) do |result|
        assert_match(/Warn.*expired/i, result.stderr, "Missing warning when attempting to reset an expired user account's password") unless host['locale'] == 'ja'
      end
    end

    step "Ensure the password wasn't changed" do
      check_password_on(host, expired_username, old_password)
    end

    teardown do
      on(host, "net user #{expired_username} /delete", accept_all_exit_codes: true)
    end
  end

  test_name 'PUP-6569 Passwords are not reset for locked accounts' do
    tag 'audit:low'
    confine :to, platform: 'windows'

    locked_username = random_username

    step "Create a user account and set account lockout threshold to zero" do
      on(host, "net user #{locked_username} /add")
      on(host, "net accounts /lockoutthreshold:1")
      on(host, "runas /user:#{locked_username} not-the-password hostname.exe", accept_all_exit_codes: true)
    end

    step "Try to change the locked-out user's password with puppet" do
      apply_manifest_on(host, set_password_manifest(locked_username)) do |result|
        assert_match(/Warn.*locked/i, result.stderr, "Missing warning when attempting to reset a locked user account's password") unless host['locale'] == 'ja'
      end
    end

    step "Ensure the password wasn't changed" do
      check_password_on(host, locked_username, old_password)
    end

    teardown do
      on(host, "net accounts /lockoutthreshold:10")
      on(host, "net user #{locked_username} /delete", accept_all_exit_codes: true)
    end
  end
end
