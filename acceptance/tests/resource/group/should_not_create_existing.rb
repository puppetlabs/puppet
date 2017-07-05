test_name "group should not create existing group"
confine :except, :platform => /^cisco_/ # See PUP-5828
tag 'audit:high',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

name = "gr#{rand(999999).to_i}"

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
