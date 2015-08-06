test_name "verifies that puppet resource creates a user and assigns the correct group"
confine :except, :platform => 'windows'

user = "pl#{rand(999999).to_i}"
group = "gp#{rand(999999).to_i}"

agents.each do |host|
  step "user should not exist"
  agent.user_absent(user)

  step "group should exist"
  agent.group_present(group)

  step "create user with group"
  on(host, puppet_resource('user', user, 'ensure=present', "gid=#{group}"))

  step "verify the group exists and find the gid"
  group_gid = agent.group_gid(group)

  step "verify that the user has that as their gid"
  agent.user_get(user) do |result|
    if agent['platform'] =~ /osx/
        match = result.stdout.match(/gid: (\d+)/)
        user_gid = match ? match[1] : nil
    else
        user_gid = result.stdout.split(':')[3]
    end

    fail_test "expected gid #{group_gid} but got: #{user_gid}" unless group_gid == user_gid
  end

  step "clean up after the test is done"
  on(host, puppet_resource('user', user, 'ensure=absent'))
  on(host, puppet_resource('group', group, 'ensure=absent'))
end
