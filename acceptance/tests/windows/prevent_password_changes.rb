test_name 'PUP-6569 Puppet should not reset passwords for disabled, expired, or locked out Windows user accounts' do
  require 'date'
  require 'puppet/acceptance/windows_utils'

  extend Puppet::Acceptance::WindowsUtils
  confine :to, platform: 'windows'

  def random_username
    "pl#{rand(999999).to_i}"
  end

  def change_password_manifest(username)
    return <<-MANIFEST
    user { '#{username}':
      ensure   => 'present',
      password => 'Password-#{rand(999999).to_i}'
    }
    MANIFEST
  end

  OLD_PASSWORD='0ldP@ssword'

  agents.each do |host|
    disabled_username = random_username

    step "Create a disabled user account" do
      on(host, "cmd.exe /c net user #{disabled_username} /active:no /add")
    end

    step "Try to change the disabled user account's password with puppet" do
      apply_manifest_on(host, change_password_manifest(disabled_username))
    end

    step "Ensure the password wasn't changed" do
      assert_password_matches_on(host, disabled_username, OLD_PASSWORD, "Expected the disabled user account's password to remain unchanged")
    end

    expired_username = random_username

    step "Create an expired user account" do
      date_format = host["locale"] == "ja" ? "%y/%m/%d" : "%m/%d/%y"
      on(host, "cmd.exe /c net user #{expired_username} /expires:#{(Date.today - 1).strftime(date_format)} /add")
    end

    step "Try to change the expired user's password with puppet" do
      apply_manifest_on(host, change_password_manifest(expired_username))
    end

    step "Ensure the password wasn't changed" do
      assert_password_matches_on(host, expired_username, OLD_PASSWORD, "Expected the expired user account's password to remain unchanged")
    end

    locked_username = random_username

    step "Create a user account, lower the account lockout threshold, and lock the new account by using the wrong password" do
      on(host, "cmd.exe /c net user #{locked_username} /add")
      on(host, "cmd.exe /c net accounts /lockoutthreshold:1")
      on(host, "cmd.exe /c runas /user:#{locked_username} hostname.exe", accept_all_exit_codes: true)
    end

    step "Try to change the locked account's password with puppet" do
      apply_manifest_on(host, change_password_manifest(locked_username))
    end

    step "Ensure the password wasn't changed" do
      assert_password_matches_on(host, locked_username, OLD_PASSWORD, "Expected the locked out user account's password to remain unchanged")
    end

    teardown do
      on(host, "cmd.exe /c net accounts /lockoutthreshold:10")
      host.user_absent(disabled_username)
      host.user_absent(expired_username)
      host.user_absent(locked_username)
    end
  end
end
