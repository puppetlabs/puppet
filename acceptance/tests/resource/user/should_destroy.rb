test_name "should delete a user"

name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  step "making_sure the user is present"
  agent.user_present(name)

  step "delete the user"
  on agent, puppet_resource('user', name, 'making_sure=absent')

  step "verify the user was deleted"
  agent.user_absent(name)
end
