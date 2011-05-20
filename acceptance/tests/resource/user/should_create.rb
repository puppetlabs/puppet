test_name "should create a user, and the default matching group"
# REVISIT: This is a direct port of the original test, but it contains a
# non-portable assumption that "user private groups" are used by default by
# everything that we target. --daniel 2010-12-24

name = "test-user-#{Time.new.to_i}"

step "ensure that the user and group #{name} do not exist"
on agents, "if getent passwd #{name}; then userdel #{name}; fi"
on agents, "if getent group #{name}; then groupdel #{name}; fi"

step "ask puppet to create the user"
on(agents, puppet_resource('user', name, 'ensure=present'))

step "verify that the user and group now exist"
on agents, "getent passwd #{name} && getent group #{name}"

step "ensure that the user and group #{name} do not exist"
on agents, "if getent passwd #{name}; then userdel #{name}; fi"
on agents, "if getent group #{name}; then groupdel #{name}; fi"
