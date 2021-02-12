test_name "verify that we can modify the gid with forcelocal" do
  confine :to, :platform => /el|fedora/ # PUP-5358

  require 'puppet/acceptance/common_utils'
  extend Puppet::Acceptance::PackageUtils
  extend Puppet::Acceptance::ManifestUtils

  tag 'audit:high'

  user = "u#{rand(99999).to_i}"
  group1 = "#{user}o"
  group2 = "#{user}n"

  agents.each do |host|
    teardown do
      on(host, puppet_resource('user',  user,   'ensure=absent'))
      on(host, puppet_resource('group', group1, 'ensure=absent'))
      on(host, puppet_resource('group', group2, 'ensure=absent'))
    end

    step "ensure that the groups both exist" do
      on(host, puppet_resource('group', group1, 'ensure=present'))
      on(host, puppet_resource('group', group2, 'ensure=present'))
    end

    step "ensure the user exists and has the old group" do
      apply_manifest_on(agent, resource_manifest('user', user, ensure: 'present', gid: group1, forcelocal: true))
    end

    step "verify that the user has the correct gid" do
      group_gid1 = host.group_gid(group1)
      host.user_get(user) do |result|
        user_gid1 = result.stdout.split(':')[3]

        fail_test "didn't have the expected old GID #{group_gid1}, but got: #{user_gid1}" unless group_gid1 == user_gid1
      end
    end

    step "modify the GID of the user" do
      apply_manifest_on(agent, resource_manifest('user', user, ensure: 'present', gid: group2, forcelocal: true), expect_changes: true)
    end

    step "verify that the user has the updated gid" do
      group_gid2 = host.group_gid(group2)
      host.user_get(user) do |result|
        user_gid2 = result.stdout.split(':')[3]

        fail_test "didn't have the expected old GID #{group_gid}, but got: #{user_gid2}" unless group_gid2 == user_gid2
      end
    end

    step "run again for idempotency" do
      apply_manifest_on(agent, resource_manifest('user', user, ensure: 'present', gid: group2, forcelocal: true), catch_changes: true)
    end
  end
end
