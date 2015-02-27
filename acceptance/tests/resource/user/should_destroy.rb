test_name "should delete a user"

name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  step "ensure the user is present"
  agent.user_present(name)

  step "delete the user"
  on agent, puppet_resource('user', name, 'ensure=absent')

  step "verify the user was deleted"
  fail_test "User #{name} was not deleted" if agent.user_list.include? name

  step "delete the user, if any"
  agent.user_absent(name)
end
