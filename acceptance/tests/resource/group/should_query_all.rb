test_name "should query all groups"

tag 'audit:high',
    'audit:refactor',   # Use block style `test_name`
    'audit:integration' # Does not modify system running test

agents.each do |agent|
  skip_test('this test fails on windows French due to Cygwin/UTF Issues - PUP-8319,IMAGES-492') if agent['platform'] =~ /windows/ && agent['locale'] == 'fr'
  step "query natively"

  # [PA-4555] Added below code to enable SSH permissions before test starts if they are disabled by default
  on(agent, 'dscl . list /Groups | grep com.apple.access_ssh') do
    stdout.each_line do |line|
      if line =~ /com.apple.access_ssh-disabled/
        on(agent, 'dscl . change /Groups/com.apple.access_ssh-disabled RecordName com.apple.access_ssh-disabled com.apple.access_ssh')
      end
    end
  end

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
