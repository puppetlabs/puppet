test_name "test that we can query and find a user that exists."

name = "test-user-#{Time.new.to_i}"

step "ensure that our test user exists"
on(agents, puppet_resource('user', name, 'ensure=present'))

step "query for the resource and verify it was found"
on(agents, puppet_resource('user', name)) do
    fail_test "didn't find the user #{name}" unless stdout.include? 'present'
end

step "clean up the user and group we added"
on(agents, puppet_resource('user', name, 'ensure=absent'))
on(agents, puppet_resource('group', name, 'ensure=absent'))
