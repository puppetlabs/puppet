test_name "verifies that puppet resource creates a user and assigns the correct group"
confine :except, :platform => 'windows'
confine :except, :platform => /^eos-/ # See ARISTA-37
confine :except, :platform => /^cisco_/ # See PUP-5828
tag 'audit:medium',
    'audit:refactor',  # Use block style `test_run`
    'audit:acceptance' # Could be done as integration tests, but would
                       # require changing the system running the test
                       # in ways that might require special permissions
                       # or be harmful to the system running the test

user = "pl#{rand(999999).to_i}"
group = "gp#{rand(999999).to_i}"

agents.each do |host|
  step "user should not exist"
  host.user_absent(user)

  step "group should exist"
  host.group_present(group)

  step "create user with group"
  on(host, puppet_resource('user', user, 'ensure=present', "gid=#{group}"))

  step "verify the group exists and find the gid"
  group_gid = host.group_gid(group)

  step "verify that the user has that as their gid"
  host.user_get(user) do |result|
    if host['platform'] =~ /osx/
        match = result.stdout.match(/gid: (\d+)/)
        user_gid = match ? match[1] : nil
    elsif host['platform'] =~ /aix/
        match = result.stdout.match(/pgrp=([^\s\\]+)/)
        user_gid = match ? host.group_gid(match[1]) : nil
    else
        user_gid = result.stdout.split(':')[3]
    end

    fail_test "expected gid #{group_gid} but got: #{user_gid}" unless group_gid == user_gid
  end

  step "clean up after the test is done"
  on(host, puppet_resource('user', user, 'ensure=absent'))
  on(host, puppet_resource('group', group, 'ensure=absent'))
end
