test_name "should not destroy a group that doesn't exist"

name = "test-group-#{Time.new.to_i}"

step "verify the group does not already exist"
agents.each do |agent|
  agent.group_absent(name)
end

step "verify that we don't remove the group when it doesn't exist"
on(agents, puppet_resource('group', name, 'ensure=absent')) do
  fail_test "it looks like we tried to remove the group" if
    stdout.include? "/Group[#{name}]/ensure: removed"
end

