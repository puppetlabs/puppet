test_name "should manage user shell"

tag 'audit:medium',
    'audit:refactor',  # Use block style `test_run`
    'audit:acceptance' # Could be done as integration tests, but would
                       # require changing the system running the test
                       # in ways that might require special permissions
                       # or be harmful to the system running the test

name = "pl#{rand(999999).to_i}"

confine :except, :platform => 'windows'
confine :except, :platform => /^eos-/ # See ARISTA-37
confine :except, :platform => /^cisco_/ # See PUP-5828

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
