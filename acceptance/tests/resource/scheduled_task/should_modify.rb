test_name "should modify a scheduled task"

name = "pl#{rand(999999).to_i}"
confine :to, :platform => 'windows'

agents.each do |agent|
  # Have to use /v1 parameter for Vista and later, older versions
  # don't accept the parameter
  version = '/v1'
  on agents, facter('kernelmajversion') do
    version = '' if stdout.chomp.to_f < 6.0
  end

  step "create the task"
  on agent, "schtasks.exe /create #{version} /tn #{name} /tr c:\\\\windows\\\\system32\\\\notepad.exe /sc daily /ru system"

  step "modify the task"
  on agent, puppet_resource('scheduled_task', name, ['ensure=present', 'command=c:\\\\windows\\\\system32\\\\notepad2.exe', "arguments=args-#{name}"])

  step "verify the arguments were updated"
  on agent, puppet_resource('scheduled_task', name) do
    assert_match(/command\s*=>\s*'c:\\windows\\system32\\notepad2.exe'/, stdout)
    assert_match(/arguments\s*=>\s*'args-#{name}'/, stdout)
  end

  step "delete the task"
  on agent, "schtasks.exe /delete /tn #{name} /f"
end
