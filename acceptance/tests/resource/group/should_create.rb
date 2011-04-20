test_name "should create group"

name = "test-group-#{Time.new.to_i}"

def cleanup(name)
    step "remove group #{name} if it exists"
    on agents, "if getent group #{name}; then groupdel #{name}; fi"
end

cleanup(name)

step "create the group #{name} with the resource agent"
on(agents, puppet_resource('group', name, 'ensure=present'))

step "verify the group #{name} was created"
on(agents, "getent group #{name}") do
    fail_test "group information is not sensible" unless stdout =~ /^#{name}:x:[0-9]+:/
end

cleanup(name)
