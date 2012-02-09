test_name "group should not create existing group"

name = "test-group-#{Time.new.to_i}"

agents.each do |agent|
  step "ensure the group exists on the target node"
  agent.group_present(name)

  step "verify that we don't try and create the existing group"
  on(agent, puppet_resource('group', name, 'ensure=present')) do
    fail_test "looks like we created the group" if
      stdout.include? "/Group[#{name}]/ensure: created"
  end

  step "clean up the system after the test run"
  agent.group_absent(name)
end
