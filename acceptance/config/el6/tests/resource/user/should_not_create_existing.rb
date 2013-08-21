test_name "tests that user resource will not add users that already exist."

step "verify that we don't try to create a user account that already exists"
agents.each do |agent|
  on(agent, puppet_resource('user', agent['user'], 'ensure=present')) do
    fail_test "tried to create '#{agent['user']}' user" if stdout.include? 'created'
  end
end
