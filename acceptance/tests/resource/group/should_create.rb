test_name "should create a group"

name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  step "making_sure the group does not exist"
  agent.group_absent(name)

  step "create the group"
  on agent, puppet_resource('group', name, 'making_sure=present')

  step "verify the group exists"
  agent.group_get(name)

  step "delete the group"
  agent.group_absent(name)
end
