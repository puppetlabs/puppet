test_name 'Puppet should change passwords for disabled, expired, or locked out Windows user accounts' do

  tag 'audit:medium',
      'audit:acceptance'

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
      password => '#{NEW_PASSWORD}'
    }
    MANIFEST
  end

  INITIAL_PASSWORD='iP@ssword'
  NEW_PASSWORD="Password-#{rand(999999).to_i}"

  agents.each do |host|
    disabled_username = random_username

    step "Create a disabled user account" do
      on(host, "cmd.exe /c net user #{disabled_username} #{INITIAL_PASSWORD} /active:no /add")
    end

    step "Change the disabled user account's password with puppet" do
      apply_manifest_on(host, change_password_manifest(disabled_username))
    end

    step "Enabling the user account as the AccountManagement context can't verify disabled users" do
      on(host, "cmd.exe /c net user #{disabled_username} /active:yes")
    end

    step "Ensure the password was changed" do
      assert_password_matches_on(host, disabled_username, NEW_PASSWORD, "Expected the disabled user account's password to be changed")
    end

    expired_username = random_username

    step "Create an expired user account" do
      date_format = host["locale"] == "ja" ? "%y/%m/%d" : "%m/%d/%y"
      on(host, "cmd.exe /c net user #{expired_username} #{INITIAL_PASSWORD} /expires:#{(Date.today - 1).strftime(date_format)} /add")
    end

    step "Change the expired user's password with puppet" do
      apply_manifest_on(host, change_password_manifest(expired_username))
    end

    step "Make expired user valid, as AccountManagement context can't verify expired user credentials" do
      date_format = host["locale"] == "ja" ? "%y/%m/%d" : "%m/%d/%y"
      on(host, "cmd.exe /c net user #{expired_username} /expires:#{(Date.today + 1).strftime(date_format)}")
      on(host, "cmd.exe /c net user #{expired_username} /active:yes")
    end

    step "Ensure the password was changed" do
      assert_password_matches_on(host, expired_username, NEW_PASSWORD, "Expected the expired user account's password to be changed")
    end

    locked_username = random_username

    step "Create a user account, lower the account lockout threshold, and lock the new account by using the wrong password" do
      on(host, "cmd.exe /c net user #{locked_username} #{INITIAL_PASSWORD} /add")
      on(host, "cmd.exe /c net accounts /lockoutthreshold:1")
      on(host, "cmd.exe /c runas /user:#{locked_username} hostname.exe", accept_all_exit_codes: true)
    end

    step "Change the locked account's password with puppet" do
      apply_manifest_on(host, change_password_manifest(locked_username))
    end

    step "Unlock the account(set it as active) as AccountManagement context can't verify credentials of locked out accounts" do
      on(host, "cmd.exe /c net user #{locked_username} /active:yes")
    end

    step "Ensure the password was changed" do
      assert_password_matches_on(host, locked_username, NEW_PASSWORD, "Expected the locked out user account's password to be changed")
    end

    teardown do
      on(host, "cmd.exe /c net accounts /lockoutthreshold:0")
      host.user_absent(disabled_username)
      host.user_absent(expired_username)
      host.user_absent(locked_username)
    end
  end
end
