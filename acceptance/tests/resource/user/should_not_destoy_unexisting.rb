test_name "ensure that puppet does not report removing a user that does not exist"

name = "pl#{rand(999999).to_i}"

step "verify that user #{name} does not exist"
on agents, "getent passwd #{name}", :acceptable_exit_codes => [2]

step "ensure absent doesn't try and do anything"
on(agents, puppet_resource('user', name, 'ensure=absent')) do
    fail_test "tried to remove the user, apparently" if stdout.include? 'removed'
end
