test_name "should delete a scheduled task"

tag 'audit:medium',
    'audit:refactor',  # Use block style `test_name`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

name = "pl#{rand(999999).to_i}"
confine :to, :platform => 'windows'

agents.each do |agent|
  # Have to use /v1 parameter for Vista and later, older versions
  # don't accept the parameter
  version = '/v1'
  # query only supports /tn parameter on Vista and later
  query_cmd = "schtasks.exe /query /v /fo list /tn #{name}"
  on agent, facter('kernelmajversion') do
    if stdout.chomp.to_f < 6.0
      version = ''
      query_cmd = "schtasks.exe /query /v /fo list | grep #{name}"
    end
  end

  step "create the task"
  on agent, "schtasks.exe /create #{version} /tn #{name} /tr c:\\\\windows\\\\system32\\\\notepad.exe /sc daily /ru system"

  step "delete the task"
  on agent, puppet_resource('scheduled_task', name, 'ensure=absent')

  step "verify the task was deleted"
  Timeout.timeout(30) do
    loop do
      step "Win32::TaskScheduler#delete call seems to be asynchronous, so we my need to test multiple times"
      on agent, query_cmd, :acceptable_exit_codes => [0,1]
      break if exit_code == 1
      sleep 1
    end
  end
  fail_test "Unable to verify that scheduled task was removed" unless exit_code == 1
end
