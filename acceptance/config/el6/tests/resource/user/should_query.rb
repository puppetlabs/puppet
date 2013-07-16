test_name "test that we can query and find a user that exists."

name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  step "ensure that our test user exists"
  agent.user_present(name)

  step "query for the resource and verify it was found"
  on(agent, puppet_resource('user', name)) do
    fail_test "didn't find the user #{name}" unless stdout.include? 'present'
  end

  step "clean up the user and group we added"
  agent.user_absent(name)
  agent.group_absent(name)
end
