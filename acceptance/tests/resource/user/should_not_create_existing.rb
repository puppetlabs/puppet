test_name "tests that user resource will not add users that already exist."
confine :except, :platform => /^eos-/ # See ARISTA-37
confine :except, :platform => /^cisco_/ # See PUP-5828
tag 'audit:medium',
    'audit:refactor',  # Use block style `test_run`
    'audit:acceptance' # Could be done as integration tests, but would
                       # require changing the system running the test
                       # in ways that might require special permissions
                       # or be harmful to the system running the test

user  = "u#{rand(999999).to_i}"
group = "g#{rand(999999).to_i}"

teardown do
  hosts.each do |host|
    host.user_absent(user)
    host.group_absent(group)
  end
end

step "Setup: Create test user and group" do
  hosts.each do |host|
    host.user_present(user)
    host.group_present(group)
  end
end

step "verify that we don't try to create a user account that already exists"
agents.each do |agent|
  on(agent, puppet_resource('user', user, 'ensure=present')) do
    fail_test "tried to create '#{user}' user" if stdout.include? 'created'
  end
end
