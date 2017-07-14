test_name "should not destroy a group that doesn't exist"
confine :except, :platform => /^cisco_/ # See PUP-5828
tag 'audit:high',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

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

