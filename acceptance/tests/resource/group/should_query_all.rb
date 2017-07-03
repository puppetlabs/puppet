test_name "should query all groups"
confine :except, :platform => /^cisco_/ # See PUP-5828
tag 'audit:high',
    'audit:refactor',   # Use block style `test_name`
    'audit:integration' # Does not modify system running test

agents.each do |agent|
  step "query natively"
  groups = agent.group_list

  fail_test("No groups found") unless groups

  step "query with puppet"
  on(agent, puppet_resource('group')) do
    stdout.each_line do |line|
      name = ( line.match(/^group \{ '([^']+)'/) or next )[1]

      unless groups.delete(name)
        fail_test "group #{name} found by puppet, not natively"
      end
    end
  end

  if groups.length > 0 then
    fail_test "#{groups.length} groups found natively, not puppet: #{groups.join(', ')}"
  end
end
