test_name "should correctly manage the password property on Windows" do
  confine :to, :platform => /windows/
  
  tag 'audit:medium',
      'audit:acceptance' # Could be done as integration tests, but would
                         # require changing the system running the test
                         # in ways that might require special permissions
                         # or be harmful to the system running the test

  require 'puppet/acceptance/common_utils.rb'
  extend Puppet::Acceptance::ManifestUtils

  require 'puppet/acceptance/windows_utils.rb'
  extend Puppet::Acceptance::WindowsUtils

  agents.each do |agent|
    username="pl#{rand(999999).to_i}"
    agent.user_absent(username)
    teardown { agent.user_absent(username) }

    current_password = 'my_password'

    step "Ensure that the user can be created with the specified password" do
      manifest = user_manifest(username, ensure: :present, password: current_password)

      apply_manifest_on(agent, manifest)
      assert_password_matches_on(agent, username, current_password, "Puppet fails to set the user's password when creating the user!")
    end

    step "Verify that the user's password is set to never expire" do
      attributes = current_attributes_on(agent, username)
      assert_equal(attributes['password_never_expires'], 'true', "Puppet fails to set the user's password to never expire")
    end

    step "Ensure that Puppet noops when the password is already set" do
      manifest = user_manifest(username, password: current_password)

      apply_manifest_on(agent, manifest, catch_changes: true)
    end

    current_password = 'new_password'

    step "Ensure that Puppet can change the user's password" do
      manifest = user_manifest(username, password: current_password)

      apply_manifest_on(agent, manifest)
      assert_password_matches_on(agent, username, current_password, "Puppet fails to change the user's password!")
    end

    step "Verify that the user's password is still set to never expire" do
      attributes = current_attributes_on(agent, username)
      assert_equal(attributes['password_never_expires'], 'true', "Puppet fails to set the user's password to never expire")
    end
  end
end
