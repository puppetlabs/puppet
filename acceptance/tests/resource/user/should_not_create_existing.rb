test_name "tests that user resource will not add users that already exist." do
  confine :except, :platform => /^eos-/ # See ARISTA-37
  confine :except, :platform => /^cisco_/ # See PUP-5828
  tag 'audit:medium',
      'audit:acceptance' # Could be done as integration tests, but would
                         # require changing the system running the test
                         # in ways that might require special permissions
                         # or be harmful to the system running the test

  user  = "u#{rand(999999).to_i}"
  group = "g#{rand(999999).to_i}"

  teardown do
    agents.each do |agent|
      agent.user_absent(user)
      agent.group_absent(group)
    end
  end

  step "Setup: Create test user and group" do
    agents.each do |agent|
      agent.user_present(user)
      agent.group_present(group)
    end
  end

  step "verify that we don't try to create a user account that already exists" do
    agents.each do |agent|
      on(agent, puppet_resource('user', user, 'ensure=present')) do
        fail_test "tried to create '#{user}' user" if stdout.include? 'created'
      end
    end
  end

end
