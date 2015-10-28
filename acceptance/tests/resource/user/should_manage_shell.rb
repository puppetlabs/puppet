test_name "should manage user shell"

name = "pl#{rand(999999).to_i}"

confine :except, :platform => 'windows'
confine :except, :platform => /eos/ # See ARISTA-37

agents.each do |agent|
  step "ensure the user and group do not exist"
  agent.user_absent(name)
  agent.group_absent(name)

  step "create the user with shell"
  shell = '/bin/sh'
  on agent, puppet_resource('user', name, ["ensure=present", "shell=#{shell}"])

  step "verify the user shell matches the managed shell"
  agent.user_get(name) do |result|
    fail_test "didn't set the user shell for #{name}" unless result.stdout.include? shell
  end

  step "modify the user with shell"

  # We need to use an allowed shell in AIX, as according to `/etc/security/login.cfg`
  if agent['platform'] =~ /aix/
    shell = '/bin/ksh'
  else
    shell = '/bin/bash'
  end

  on agent, puppet_resource('user', name, ["ensure=present", "shell=#{shell}"])

  step "verify the user shell matches the managed shell"
  agent.user_get(name) do |result|
    fail_test "didn't set the user shell for #{name}" unless result.stdout.include? shell
  end

  step "delete the user, and group, if any"
  agent.user_absent(name)
  agent.group_absent(name)
end
