test_name "should create a user"
confine :except, :platform => /^eos-/ # See ARISTA-37
confine :except, :platform => /^cisco_/ # See PUP-5828

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
