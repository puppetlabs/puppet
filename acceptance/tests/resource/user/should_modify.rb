test_name "should modify a user"

name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  step "ensure the user is present"
  agent.user_present(name)

  step "modify the user"
  on agent, puppet_resource('user', name, ["ensure=present", "comment=comment#{name}"])

  step "verify the user was modified"
  agent.user_get(name) do |result|
    fail_test "didn't modify the user #{name}" unless result.stdout.include? "comment#{name}"
  end

  step "delete the user"
  agent.user_absent(name)
  agent.group_absent(name)
end
