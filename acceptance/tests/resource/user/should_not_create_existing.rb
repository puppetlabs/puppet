test_name "tests that user resource will not add users that already exist."

step "verify that we don't try to create a user account that already exists"
on(agents, puppet_resource('user', 'root', 'ensure=present')) do
    fail_test "tried to create 'root' user" if stdout.include? 'created'
end
