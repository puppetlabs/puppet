test_name "should create a user"
confine :except, :platform => /^eos-/ # See ARISTA-37
confine :except, :platform => /^cisco_/ # See PUP-5828
tag 'audit:medium',
    'audit:refactor',  # Use block style `test_run`
    'audit:acceptance' # Could be done as integration tests, but would
                       # require changing the system running the test
                       # in ways that might require special permissions
                       # or be harmful to the system running the test

name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  step "ensure the user and group do not exist"
  agent.user_absent(name)
  agent.group_absent(name)

  step "create the user"
  on agent, puppet_resource('user', name, 'ensure=present')

  step "verify the user exists"
  agent.user_get(name)

  case agent['platform']
  when /sles/, /solaris/, /windows/, /osx/, /aix/
    # no private user groups by default
  else
    agent.group_get(name)
  end

  step "delete the user, and group, if any"
  agent.user_absent(name)
  agent.group_absent(name)
end
