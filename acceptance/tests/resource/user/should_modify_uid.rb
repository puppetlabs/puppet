test_name "should modify the uid of an user OS X < 10.14" do
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

    step "verify that the user has the correct uid" do
      new_uid = rand(999999)
      user_manifest = resource_manifest('user', user, ensure: 'present', uid: new_uid)
      apply_manifest_on(agent, user_manifest)

      agent.user_get(user) do |result|
        user_uid = Integer(result.stdout.split(':')[2])
        assert_equal(user_uid, new_uid, "Expected uid: #{new_uid}, actual uid: #{user_uid}")
      end
    end
  end
end
