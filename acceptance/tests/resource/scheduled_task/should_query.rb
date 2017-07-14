test_name "test that we can query and find a scheduled task that exists."

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
  kernel_maj_version = on(agent, facter('kernelmajversion')).stdout.chomp.to_f
  version = kernel_maj_version < 6.0 ? '' : '/v1'

  step "create the task"
  on agent, "schtasks.exe /create #{version} /tn #{name} /tr c:\\\\windows\\\\system32\\\\notepad.exe /sc daily /ru system"

  step "query for the task and verify it was found"
  on agent, puppet_resource('scheduled_task', name) do
    fail_test "didn't find the scheduled_task #{name}" unless stdout.include? 'present'
  end

  step "delete the task"
  on agent, "schtasks.exe /delete /tn #{name} /f"
end
