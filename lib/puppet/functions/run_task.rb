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
  dispatch :run_task do
    param 'Object', :task
    repeated_param 'String', :hosts
  end

  def run_task(task, *hosts)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
        {:operation => 'run_task'})
    end

    unless Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(Puppet::Pops::Issues::TASK_MISSING_BOLT)
    end

    if hosts.empty?
      call_function('notice', "Simulating run of task #{task._pcore_type.name} - no hosts given - no action taken")
      return nil
    end

    executor = Bolt::Executor.from_uris(hosts)

    # TODO: separate handling of default since it's platform specific
    input_method = task._pcore_type['input_method'].value

    # Should have a uniform way to retrieve arguments
    arguments = if task.respond_to?(:args)
                  task.args
                else
                  task._pcore_init_hash
                end
    raw_results = executor.run_task(task.executable_path, input_method, arguments)

    results = {}
    raw_results.each do |node, result|
      results[node.uri] = result
    end

    results.map do |host, result|
      output = result.output_string
      if result.success?
        output
      else
        result.exit_code
      end
    end
  end
end
