test_name "should query all groups"
skip_test if agents.any? {|agent| agent['platform'] =~ /osx-12-arm64/ || agent['platform'] =~ /osx-13-arm64/  } # See PA-4555

tag 'audit:high',
    'audit:refactor',   # Use block style `test_name`
    'audit:integration' # Does not modify system running test

agents.each do |agent|
  skip_test('this test fails on windows French due to Cygwin/UTF Issues - PUP-8319,IMAGES-492') if agent['platform'] =~ /windows/ && agent['locale'] == 'fr'
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
