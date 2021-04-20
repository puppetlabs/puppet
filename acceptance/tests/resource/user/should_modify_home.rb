test_name "should modify the home directory of an user on OS X < 10.14" do
  confine :to, :platform => /osx/
  confine :except, :platform => /(osx-10.1[4-9]|osx-11-)/

  tag 'audit:high',
      'audit:acceptance' # Could be done as integration tests, but would
                         # require changing the system running the test
                       # in ways that might require special permissions
                       # or be harmful to the system running the test

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::BeakerUtils
  extend Puppet::Acceptance::ManifestUtils

  user = "pl#{rand(999999).to_i}"

  agents.each do |agent|
    teardown do
      agent.user_absent(user)
    end

    step "ensure the user is present" do
      agent.user_present(user)
    end

    step "verify that the user has the correct home" do
      new_home = "/opt/#{user}"
      user_manifest = resource_manifest('user', user, ensure: 'present', home: new_home)
      apply_manifest_on(agent, user_manifest)

      agent.user_get(user) do |result|
        user_home = result.stdout.split(':')[8]
        assert_equal(user_home, new_home, "Expected home: #{new_home}, actual home: #{user_home}")
      end
    end
  end
end
