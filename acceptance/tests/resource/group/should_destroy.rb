test_name "should destroy a group"

name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  step "making_sure the group is present"
  agent.group_present(name)

  step "delete the group"
  on agent, puppet_resource('group', name, 'making_sure=absent')

  step "verify the group was deleted"
  agent.group_absent(name)
end
