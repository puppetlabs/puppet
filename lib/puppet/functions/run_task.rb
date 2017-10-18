# Runs a given instance of a `Task` on the given set of nodes and returns the result from each.
#
# * This function does nothing if the list of nodes is empty.
# * It is possible to run on the node 'localhost'
# * A node is a String with a node's hostname or a URI that also describes how to connect and run the task on that node
#   including "user" and "password" parts of a URI.
# * The returned value contains information about the result per node. TODO: needs mapping to a runtime Pcore Object to be useful
#
#
# Since > 5.4.0 TODO: Update when version is known
#
Puppet::Functions.create_function(:run_task) do
  local_types do
    type 'NodeOrNodes = Variant[String[1], Array[NodeOrNodes]]'
  end

  dispatch :run_task_type do
    param 'Type[Task]', :task_type
    param 'NodeOrNodes', :nodes
    optional_param 'Hash[String[1], Any]', :task_args
  end

  dispatch :run_named_task do
    param 'String[1]', :task_type
    param 'NodeOrNodes', :nodes
    optional_param 'Hash[String[1], Any]', :task_args
  end

  dispatch :run_task_instance do
    param 'Task', :task
    repeated_param 'NodeOrNodes', :nodes
  end

  def run_task_type(task_type, nodes, task_args = nil)
    use_args = task_args.nil? ? {} : task_args
    task_instance = call_function('new', task_type, use_args)
    run_task_instance(task_instance, nodes)
  end

  def run_named_task(task_name, nodes, task_args = nil)
    task_type = Puppet.lookup(:loaders).private_environment_loader.load(:type, task_name)
    if task_type.nil?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(Puppet::Pops::Issues::UNKNOWN_TASK, :type_name => task_name)
    end
    use_args = task_args.nil? ? {} : task_args
    task_instance = call_function('new', task_type, use_args)
    run_task_instance(task_instance, nodes)
  end

  def run_task_instance(task, *nodes)
    hosts = nodes.flatten
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
        {:operation => 'run_task'})
    end

    executor = Puppet.lookup(:bolt_executor) { nil }
    unless executor && Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(Puppet::Pops::Issues::TASK_MISSING_BOLT, :action => _('run a task'))
    end

    if hosts.empty?
      call_function('debug', "Simulating run of task #{task._pcore_type.name} - no hosts given - no action taken")
      Puppet::Pops::Types::ExecutionResult::EMPTY_RESULT
    else
      # TODO: separate handling of default since it's platform specific
      input_method = task._pcore_type['input_method'].value

      arguments = task.task_args
      Puppet::Pops::Types::ExecutionResult.from_bolt(
        executor.run_task(
          executor.from_uris(hosts), task.executable_path, input_method, arguments
        )
      )
    end
  end
end
