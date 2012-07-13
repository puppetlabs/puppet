test_name "should delete a scheduled task"

name = "pl#{rand(999999).to_i}"
confine :to, :platform => 'windows'

agents.each do |agent|
  # Have to use /v1 parameter for Vista and later, older versions
  # don't accept the parameter
  version = '/v1'
  # query only supports /tn parameter on Vista and later
  query_cmd = "schtasks.exe /query /v /fo list /tn #{name}"
  on agents, facter('kernelmajversion') do
    if stdout.chomp.to_f < 6.0
      version = ''
      query_cmd = "schtasks.exe /query /v /fo list | grep -vq #{name}"
    end
  end

  step "create the task"
  on agent, "schtasks.exe /create #{version} /tn #{name} /tr c:\\\\windows\\\\system32\\\\notepad.exe /sc daily /ru system"

  step "delete the task"
  on agent, puppet_resource('scheduled_task', name, 'ensure=absent')

  step "verify the task was deleted"
  on agent, query_cmd
end
