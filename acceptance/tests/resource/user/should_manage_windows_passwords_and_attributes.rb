test_name "should correctly manage the password and attributes properties together on Windows" do
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

  require 'puppet/acceptance/common_tests.rb'
  extend Puppet::Acceptance::CommonTests::AttributesProperty

  agents.each do |agent|
    username="pl#{rand(999999).to_i}"
    agent.user_absent(username)
    teardown { agent.user_absent(username) }

    current_password = 'my_password'
    current_attributes = {
      'full_name' => 'Full Name'
    }

    puppet_result = nil
    step "Create the user with Puppet" do
      manifest = user_manifest(username, ensure: :present, password: current_password, attributes: current_attributes)

      puppet_result = apply_manifest_on(agent, manifest) { |result| puppet_result = result }
    end

    step "Verify that Puppet set the user's password" do
      assert_password_matches_on(agent, username, current_password, "Puppet fails to set the user's password when creating the user!")
    end

    step "Verify that Puppet set the user's attributes" do
      assert_attributes_on(agent, current_attributes, current_attributes_on(agent, username), "Puppet failed to set the user's attributes when creating the user")

    end

    step "Verify that Puppet syncs the user's attributes before syncing their password" do
      current_attributes = {
        'disabled' => true
      }

      manifest = user_manifest(username, ensure: :present, password: 'my_other_password', attributes: current_attributes)
      apply_manifest_on(agent, manifest)

      assert_attributes_on(agent, current_attributes, current_attributes_on(agent, username), "Puppet failed to modify the user's attributes. Thus, there is no way to know if it does, in fact, sync. the attributes property before the password property.")
      assert_password_matches_on(agent, username, current_password, "Puppet does not sync the user's attributes before their password. This failure was detected by having Puppet disable the user account _and_ change their password in the same run. The correct behavior was to disable the user account _without_ changing their password, which can only happen if the attributes property is synced before the password property. Instead, Puppet changed the user's password despite disabling their account.")
    end

    step "Reset the user's attributes" do
      current_attributes = {
        'disabled' => false
      }

      manifest = user_manifest(username, ensure: :present, attributes: current_attributes)
      apply_manifest_on(agent, manifest)

      assert_attributes_on(agent, current_attributes, current_attributes_on(agent, username), "Puppet failed to reset the user's attributes")
    end

    step "Change the user's password while managing the attributes property" do
      current_password = 'my_other_password'

      manifest = user_manifest(username, ensure: :present, password: current_password, attributes: current_attributes)
      puppet_result = apply_manifest_on(agent, manifest) { |result| puppet_result = result }
    end

    step "Verify that Puppet changed the user's password" do
      assert_password_matches_on(agent, username, current_password, "Puppet did not change the user's password while managing the attributes property.")
    end

    step "Verify that Puppet prints a warning mesage when the user does not specify the password_never_expires attribute" do
      assert_match(/Warning/, puppet_result.stderr, "Puppet does not print a warning message when it changes a user's password and the user does not specify the password_never_expires attribute")
    end
  end
end
