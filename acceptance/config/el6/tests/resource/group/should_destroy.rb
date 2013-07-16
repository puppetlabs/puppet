test_name "should destroy a group"

name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  step "ensure the group is present"
  agent.group_present(name)

  step "delete the group"
  on agent, puppet_resource('group', name, 'ensure=absent')

  step "verify the group was deleted"
  agent.group_absent(name)
end
