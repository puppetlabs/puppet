test_name "verify that puppet resource correctly destroys users"

user  = "test-user-#{Time.new.to_i}"
group = user

step "ensure that the user and associated group exist"
on(agents, puppet_resource('group', group, 'ensure=present'))
on(agents, puppet_resource('user', user, 'ensure=present', "gid=#{group}"))

step "try and delete the user"
on(agents, puppet_resource('user', user, 'ensure=absent'))

step "verify that the user is no longer present"
on(agents, "getent passwd #{user}", :acceptable_exit_codes => [2]) do
    fail_test "found the user in the output" if stdout.include? "#{user}:"
end

step "remove the group as well..."
on(agents, puppet_resource('group', group, 'ensure=absent'))
