# Runs a given instance of a `Task` on the given set of targets and returns the result from each.
#
# * This function does nothing if the list of targets is empty.
# * It is possible to run on the target 'localhost'
# * A target is a String with a targets's hostname or a Target.
# * The returned value contains information about the result per target.
#
# Since > 5.4.0 TODO: Update when version is known
#
Puppet::Functions.create_function(:run_task) do
  local_types do
    type 'TargetOrTargets = Variant[String[1], Target, Array[TargetOrTargets]]'
  end

  dispatch :run_task_type do
    param 'Type[Task]', :task_type
    param 'TargetOrTargets', :targets
    optional_param 'Hash[String[1], Any]', :task_args
  end

  dispatch :run_named_task do
    param 'String[1]', :task_type
    param 'TargetOrTargets', :targets
    optional_param 'Hash[String[1], Any]', :task_args
  end

  dispatch :run_task_instance do
    param 'Task', :task
    repeated_param 'TargetOrTargets', :targets
  end

  def run_task_type(task_type, targets, task_args = nil)
    use_args = task_args.nil? ? {} : task_args
    task_instance = call_function('new', task_type, use_args)
    run_task_instance(task_instance, targets)
  end

  def run_named_task(task_name, targets, task_args = nil)
    task_type = Puppet.lookup(:loaders).private_environment_loader.load(:type, task_name)
    if task_type.nil?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(Puppet::Pops::Issues::UNKNOWN_TASK, :type_name => task_name)
    end
    use_args = task_args.nil? ? {} : task_args
    task_instance = call_function('new', task_type, use_args)
    run_task_instance(task_instance, targets)
  end

  def run_task_instance(task, *targets)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
        {:operation => 'run_task'})
    end

    executor = Puppet.lookup(:bolt_executor) { nil }
    unless executor && Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(Puppet::Pops::Issues::TASK_MISSING_BOLT, :action => _('run a task'))
    end

    # Ensure that that given targets are all Target instances
    targets = targets.flatten.map { |t| t.is_a?(String) ? Puppet::Pops::Types::TypeFactory.target.create(t) : t }
    if targets.empty?
      call_function('debug', "Simulating run of task #{task._pcore_type.name} - no targets given - no action taken")
      Puppet::Pops::Types::ExecutionResult::EMPTY_RESULT
    else
      # Awaits change in the executor, enabling it receive Target instances
      hosts = targets.map { |h| h.host }

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
