test_name "group should not create existing group"

name = "test-group-#{Time.new.to_i}"

step "ensure the group exists on the target node"
on(agents, puppet_resource('group', name, 'ensure=present'))

step "verify that we don't try and create the existing group"
on(agents, puppet_resource('group', name, 'ensure=present')) do
    fail_test "looks like we created the group" if
        stdout.include? '/Group[bozo]/ensure: created'
end

step "clean up the system after the test run"
on(agents, puppet_resource('group', name, 'ensure=absent'))
