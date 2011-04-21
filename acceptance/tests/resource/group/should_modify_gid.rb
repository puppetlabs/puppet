test_name "should modify gid of existing group"

name = "test-group-#{Time.new.to_i}"
gid  = 12345

step "ensure that the group exists with gid #{gid}"
on(agents, puppet_resource('group', name, 'ensure=present', "gid=#{gid}")) do
    fail_test "missing gid notice" unless stdout =~ /gid +=> +'#{gid}'/
end

step "ensure that we can modify the GID of the group to #{gid*2}"
on(agents, puppet_resource('group', name, 'ensure=present', "gid=#{gid*2}")) do
    fail_test "missing gid notice" unless stdout =~ /gid +=> +'#{gid*2}'/
end

step "verify that the GID changed"
on(agents, "getent group #{name}") do
    fail_test "gid is wrong through getent output" unless
        stdout =~ /^#{name}:x:#{gid*2}:/
end

step "clean up the system after the test run"
on(agents, puppet_resource('group', name, 'ensure=absent'))
