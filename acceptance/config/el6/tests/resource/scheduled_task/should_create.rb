test_name "should create a scheduled task"

name = "pl#{rand(999999).to_i}"
confine :to, :platform => 'windows'

agents.each do |agent|
  # query only supports /tn parameter on Vista and later
  query_cmd = "schtasks.exe /query /v /fo list /tn #{name}"
  on agents, facter('kernelmajversion') do
    query_cmd = "schtasks.exe /query /v /fo list | grep -q #{name}" if stdout.chomp.to_f < 6.0
  end

  step "create the task"
  args = ['ensure=present',
          'command=c:\\\\windows\\\\system32\\\\notepad.exe',
          'arguments="foo bar baz"',
          'working_dir=c:\\\\windows']
  on agent, puppet_resource('scheduled_task', name, args)

  step "verify the task exists"
  on agent, query_cmd

  step "verify task properties"
  on agent, puppet_resource('scheduled_task', name) do
    assert_match(/command\s*=>\s*'c:\\windows\\system32\\notepad.exe'/, stdout)
    assert_match(/arguments\s*=>\s*'foo bar baz'/, stdout)
    assert_match(/enabled\s*=>\s*'true'/, stdout)
    assert_match(/working_dir\s*=>\s*'c:\\windows'/, stdout)
  end

  step "delete the task"
  on agent, "schtasks.exe /delete /tn #{name} /f"
end
