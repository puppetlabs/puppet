test_name "group should query"

name = "test-group-#{Time.new.to_i}"

step "ensure the group exists on the target systems"
on agents, "getent group #{name} || groupadd #{name}"

step "ensure that the resource agent sees the group"
on(agents, puppet_resource('group', name)) do
    fail_test "missing group identifier" unless stdout.include? "group { '#{name}':"
    fail_test "missing present attributed" unless stdout.include? "ensure => 'present'"
end

step "clean up the system after the test"
on(agents, puppet_resource('group', name, 'ensure=absent'))
