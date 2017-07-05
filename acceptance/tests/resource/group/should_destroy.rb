test_name "should destroy a group"
confine :except, :platform => /^cisco_/ # See PUP-5828
tag 'audit:high',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  step "ensure the group is present"
  agent.group_present(name)

  step "delete the group"
  on agent, puppet_resource('group', name, 'ensure=absent')

  step "verify the group was deleted"
  agent.group_absent(name)
end
