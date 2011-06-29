test_name "should modify gid of existing group"

name = "pl#{rand(999999).to_i}"
gid1  = rand(999999).to_i
gid2  = rand(999999).to_i

step "ensure that the group exists with gid #{gid1}"
on(agents, puppet_resource('group', name, 'ensure=present', "gid=#{gid1}")) do
    fail_test "missing gid notice" unless stdout =~ /gid +=> +'#{gid1}'/
end

step "ensure that we can modify the GID of the group to #{gid2}"
on(agents, puppet_resource('group', name, 'ensure=present', "gid=#{gid2}")) do
    fail_test "missing gid notice" unless stdout =~ /gid +=> +'#{gid2}'/
end

step "verify that the GID changed"
on(agents, "getent group #{name}") do
    fail_test "gid is wrong through getent output" unless
        stdout =~ /^#{name}:.*:#{gid2}:/
end

step "clean up the system after the test run"
on(agents, puppet_resource('group', name, 'ensure=absent'))
