test_name "should not modify the uid of an user on OS X >= 10.14" do
  confine :to, :platform => /osx-10.1[4-9]/

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
      user_absent(agent, user)
    end

    step "ensure the user is present" do
      agent.user_present(user)
    end

    step "verify the error message is correct" do
      expected_error = /OS X version 10\.1[4-9] does not allow changing uid using puppet/
      user_manifest = resource_manifest('user', user, ensure: 'present', uid: rand(999999))

      apply_manifest_on(agent, user_manifest) do |result|
        assert_match(
          expected_error,
          result.stderr,
          "Puppet fails to report an error when changing uid on OS X >= 10.14"
        )
      end
    end
  end
end
