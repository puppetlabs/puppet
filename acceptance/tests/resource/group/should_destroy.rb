test_name "should destroy a group"

name = "test-group-#{Time.new.to_i}"

step "ensure the group exists on the target system"
on agents, "getent group #{name} || groupadd #{name}"

step "use puppet to remove the group"
on(agents, puppet_resource('group', name, 'ensure=absent'))

step "verify that the group has been removed"
# REVISIT: I /think/ that exit code 2 is standard across Linux, but I have no
# idea what non-Linux platforms are going to return. --daniel 2010-12-24
on agents, "getent group #{name}", :acceptable_exit_codes => [2]
