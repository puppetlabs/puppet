# Runs a given instance of a `Task` on the given set of nodes and returns the result from each.
#
# * This function does nothing if the list of nodes is empty.
# * It is possible to run on the node 'localhost'
# * A node is a String with a node's hostname or a URI that also describes how to connect and run the task on that node
#   including "user" and "password" parts of a URI.
# * The returned value contains information about the result per node. TODO: needs mapping to a runtime Pcore Object to be useful
#
# Since > 5.2.0 TODO: Update when version is known
#
Puppet::Functions.create_function(:run_task) do
  dispatch :mocked_run_task do
    param 'Object', :task
    repeated_param 'String', :hosts
  end

  def mocked_run_task(task, *hosts)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
        {:operation => 'run_task'})
    end

    if hosts.empty?
      call_function('notice', "Simulating run of task #{task._pcore_type.name} - no hosts given - no action taken")
      return nil
    end

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

