# Runs a given instance of a `Task` on the given set of hosts, or localhost if no hosts are given and returns the result from each
#
# Since > 5.2.0 TODO: Update when version is known
#
Puppet::Functions.create_function(:run_task) do
  dispatch :mocked_run_task do
    param 'Object', :task
    repeated_param 'String', :hosts
  end

  def mocked_run_task(task, *hosts)
    call_function('notice', "Simulating run of task #{task._pcore_type.name} on hosts: [" + hosts.join(', ') + "]")
    hosts.map do |hostname|
      exit_code = task.respond_to?(:simulated_exit_code) ? task.exit_code : 0
      result =
      if exit_code == 0
        result = task.respond_to?(:simluated_result) ? task.simulated_result : '<simulated result>'
      else
        exit_code
      end
      call_function('notice', "Simulating run of task #{task._pcore_type.name} on '#{hostname}' with result '#{result}'")
      result
    end
  end
end

