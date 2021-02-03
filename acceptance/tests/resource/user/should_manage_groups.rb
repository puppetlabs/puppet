test_name "should correctly manage the groups property for the User resource" do
  # NOTE: These tests run for only some of our supported platforms.
  # We should eventually update them to work with all of our
  # supported platforms where managing the groups property makes
  # sense.

  confine :except, :platform => /windows/
  confine :except, :platform => /eos-/ # See ARISTA-37
  confine :except, :platform => /cisco_/ # See PUP-5828

  tag 'audit:high',
      'audit:acceptance' # Could be done as integration tests, but would
                         # require changing the system running the test
                         # in ways that might require special permissions
                         # or be harmful to the system running the test

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::BeakerUtils

  def random_name
    "pl#{rand(999999).to_i}"
  end

  def user_manifest(user, params)
    params_str = params.map do |param, value|
      value_str = value.to_s
      value_str = "\"#{value_str}\"" if value.is_a?(String)

      "  #{param} => #{value_str}"
    end.join(",\n")

    <<-MANIFEST
user { '#{user}':
  #{params_str}
}
MANIFEST
  end

  def groups_of(host, user)
    # The setup step should have already set :privatebindir on the
    # host. We only include the default here to make this routine
    # work for local testing, which sometimes skips the setup step.
    privatebindir = host.has_key?(:privatebindir) ? host[:privatebindir] : '/opt/puppetlabs/puppet/bin'

    # This bit of code reads the user's groups from the /etc/group file.
    result = on(host, "#{privatebindir}/ruby -e \"require 'puppet'; puts(Puppet::Util::POSIX.groups_of('#{user}').to_s)\"")
    Kernel.eval(result.stdout.chomp)
  end

  agents.each do |agent|
    groups = 5.times.collect { random_name }
    groups.each { |group| agent.group_absent(group) }

    # We want to ensure that Beaker destroys the user first before
    # the groups. Otherwise the teardown step will fail b/c we will
    # be trying to remove the user's primary group before removing
    # the user.
    user = random_name
    agent.user_absent(user)
    teardown { agent.user_absent(user) }

    step 'Creating the Groups' do
      groups.each do |group|
        agent.group_present(group)
        teardown { agent.group_absent(group) }
      end
    end

    user_groups = [groups[0], groups[1]]
    primary_group = groups[2]

    step 'Ensure that the user is created with the specified groups' do
      # We use inclusive membership to ensure that the user's only a member
      # of our groups and no other group.
      manifest = user_manifest(user, groups: user_groups, gid: primary_group, membership: :inclusive)
      apply_manifest_on(agent, manifest)
      assert_matching_arrays(user_groups, groups_of(agent, user), "The user was not successfully created with the specified groups!")
    end

    step "Verify that Puppet errors when one of the groups does not exist" do
      manifest = user_manifest(user, groups: ['nonexistent_group'])
      apply_manifest_on(agent, manifest) do |result|
        assert_match(/Error:.*#{user}/, result.stderr, "Puppet fails to report an error when one of the groups in the groups property does not exist")
      end
    end

    primary_group = groups[3]
    step "Verify that modifying the primary group does not change the user's groups" do
      manifest = user_manifest(user, gid: primary_group)
      apply_manifest_on(agent, manifest)
      assert_matching_arrays(user_groups, groups_of(agent, user), "The user's groups changed after modifying the primary group")
    end

    step "Verify that Puppet noops when the user's groups are already set" do
      manifest = user_manifest(user, groups: user_groups)
      apply_manifest_on(agent, manifest, catch_changes: true)
      assert_matching_arrays(user_groups, groups_of(agent, user), "The user's groups somehow changed despite Puppet reporting a noop")
    end

    step "Verify that Puppet enforces minimum group membership" do
      new_groups = [groups[2], groups[4]]

      manifest = user_manifest(user, groups: new_groups, membership: :minimum)
      apply_manifest_on(agent, manifest)

      user_groups += new_groups
      assert_matching_arrays(user_groups, groups_of(agent, user), "Puppet fails to enforce minimum group membership")
    end

    if agent['platform'] =~ /osx/
      skip_test "User provider on OSX fails to enforce inclusive group membership, so we will skip that test until this is fixed. See PUP-9160."
    end

    step "Verify that Puppet enforces inclusive group membership" do
      user_groups = [groups[0]]

      manifest = user_manifest(user, groups: user_groups, membership: :inclusive)
      apply_manifest_on(agent, manifest)
      assert_matching_arrays(user_groups, groups_of(agent, user), "Puppet fails to enforce inclusive group membership")
    end
  end
end
