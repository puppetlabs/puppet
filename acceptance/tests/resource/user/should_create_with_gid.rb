test_name "verifies that puppet resource creates a user and assigns the correct group"
confine :except, :platform => 'windows'

user = "pl#{rand(999999).to_i}"
group = "gp#{rand(999999).to_i}"

agents.each do |host|
  step "user should not exist"
  on host, "if getent passwd #{user}; then userdel #{user}; fi"

  step "group should exist"
  on host, "getent group #{group} || groupadd #{group}"

  step "create user with group"
  on(host, puppet_resource('user', user, 'ensure=present', "gid=#{group}"))

  step "verify the group exists and find the gid"
  on(host, "getent group #{group}") do
      gid = stdout.split(':')[2]

      step "verify that the user has that as their gid"
      on(host, "getent passwd #{user}") do
          got = stdout.split(':')[3]
          fail_test "wanted gid #{gid} but found #{got}" unless gid == got
      end
  end

  step "clean up after the test is done"
  on(host, puppet_resource('user', user, 'ensure=absent'))
  on(host, puppet_resource('group', group, 'ensure=absent'))
end
