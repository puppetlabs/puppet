test_name "test that we can query and find a group that exists."

name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  step "ensure that our test group exists"
  agent.group_present(name)

  step "query for the resource and verify it was found"
  on(agent, puppet_resource('group', name)) do
    fail_test "didn't find the group #{name}" unless stdout.include? 'present'
  end

  step "clean up the group we added"
  agent.group_absent(name)
end
