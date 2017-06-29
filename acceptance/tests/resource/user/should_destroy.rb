test_name "should delete a user"
confine :except, :platform => /^eos-/ # See ARISTA-37
confine :except, :platform => /^cisco_/ # See PUP-5828
tag 'audit:medium',
    'audit:refactor',  # Use block style `test_run`
    'audit:acceptance' # Could be done as integration tests, but would
                       # require changing the system running the test
                       # in ways that might require special permissions
                       # or be harmful to the system running the test

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
