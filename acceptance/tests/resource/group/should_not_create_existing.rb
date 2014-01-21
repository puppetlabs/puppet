test_name "group should not create existing group"

name = "test-group-#{Time.new.to_i}"

agents.each do |agent|
  step "making_sure the group exists on the target node"
  agent.group_present(name)

  step "verify that we don't try and create the existing group"
  on(agent, puppet_resource('group', name, 'making_sure=present')) do
    fail_test "looks like we created the group" if
      stdout.include? "/Group[#{name}]/making_sure: created"
  end

  step "clean up the system after the test run"
  agent.group_absent(name)
end
