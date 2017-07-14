test_name "verify that we can modify the gid"
confine :except, :platform => 'windows'
confine :except, :platform => /aix/ # PUP-5358
confine :except, :platform => /^eos-/ # See ARISTA-37
confine :except, :platform => /^cisco_/ # See PUP-5828
tag 'audit:medium',
    'audit:refactor',  # Use block style `test_run`
    'audit:acceptance' # Could be done as integration tests, but would
                       # require changing the system running the test
                       # in ways that might require special permissions
                       # or be harmful to the system running the test

user = "u#{rand(99999).to_i}"
group1 = "#{user}o"
group2 = "#{user}n"

agents.each do |host|
  step "ensure that the groups both exist"
  on(host, puppet_resource('group', group1, 'ensure=present'))
  on(host, puppet_resource('group', group2, 'ensure=present'))

  step "ensure the user exists and has the old group"
  on(host, puppet_resource('user', user, 'ensure=present', "gid=#{group1}"))

  step "verify that the user has the correct gid"
  group_gid1 = host.group_gid(group1)
  host.user_get(user) do |result|
    if host['platform'] =~ /osx/
        match = result.stdout.match(/gid: (\d+)/)
        user_gid1 = match ? match[1] : nil
    else
        user_gid1 = result.stdout.split(':')[3]
    end

    fail_test "didn't have the expected old GID #{group_gid1}, but got: #{user_gid1}" unless group_gid1 == user_gid1
  end

  step "modify the GID of the user"
  on(host, puppet_resource('user', user, 'ensure=present', "gid=#{group2}"))

  step "verify that the user has the updated gid"
  group_gid2 = host.group_gid(group2)
  host.user_get(user) do |result|
    if host['platform'] =~ /osx/
        match = result.stdout.match(/gid: (\d+)/)
        user_gid2 = match ? match[1] : nil
    else
        user_gid2 = result.stdout.split(':')[3]
    end

    fail_test "didn't have the expected old GID #{group_gid}, but got: #{user_gid2}" unless group_gid2 == user_gid2
  end

  step "ensure that we remove the things we made"
  on(host, puppet_resource('user',  user,   'ensure=absent'))
  on(host, puppet_resource('group', group1, 'ensure=absent'))
  on(host, puppet_resource('group', group2, 'ensure=absent'))
end
