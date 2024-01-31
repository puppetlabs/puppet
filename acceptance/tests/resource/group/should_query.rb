test_name "test that we can query and find a group that exists."

tag 'audit:high',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  skip_test('this test fails on windows French due to Cygwin/UTF Issues - PUP-8319,IMAGES-492') if agent['platform'] =~ /windows/ && agent['locale'] == 'fr'

  step "ensure that our test group exists"
  agent.group_present(name)

  step "query for the resource and verify it was found"
  on(agent, puppet_resource('group', name)) do |result|
    fail_test "didn't find the group #{name}" unless result.stdout.include? 'present'
  end

  step "clean up the group we added"
  agent.group_absent(name)
end
