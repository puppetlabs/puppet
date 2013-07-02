test_name "test that we can query and find a scheduled task that exists."

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

  step "query for the task and verify it was found"
  on agent, puppet_resource('scheduled_task', name) do
    fail_test "didn't find the scheduled_task #{name}" unless stdout.include? 'present'
  end

  step "delete the task"
  on agent, "schtasks.exe /delete /tn #{name} /f"
end
