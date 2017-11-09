# Uploads the given script to the given set of targets and returns the result of having each target execute the script.
#
# * This function does nothing if the list of targets is empty.
# * It is possible to run on the target 'localhost'
# * A target is a String with a targets's hostname or a Target.
# * The returned value contains information about the result per target.
#
# Since > 5.4.0 TODO: Update when version is known
#
Puppet::Functions.create_function(:run_script, Puppet::Functions::InternalFunction) do
  local_types do
    type 'TargetOrTargets = Variant[String[1], Target, Array[TargetOrTargets]]'
  end

  dispatch :run_script_with_args do
    scope_param
    param 'String[1]', :script
    param 'TargetOrTargets', :targets
    param 'Struct[arguments => Array[String]]', :arguments
  end

  dispatch :run_script do
    scope_param
    param 'String[1]', :script
    repeated_param 'TargetOrTargets', :targets
  end

  def run_script(scope, script, *targets)
    run_script_with_args(scope, script, targets, 'arguments' => [])
  end

  def run_script_with_args(scope, script, targets, args_hash)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
        {:operation => 'run_script'})
    end

    executor = Puppet.lookup(:bolt_executor) { nil }
    unless executor && Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(Puppet::Pops::Issues::TASK_MISSING_BOLT, :action => _('run a script'))
    end

    found = Puppet::Parser::Files.find_file(script, scope.compiler.environment)
    unless found && Puppet::FileSystem.exist?(found)
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(Puppet::Pops::Issues::NO_SUCH_FILE_OR_DIRECTORY, {:file => script})
    end
    unless Puppet::FileSystem.file?(found)
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(Puppet::Pops::Issues::NOT_A_FILE, {:file => script})
    end

    # Ensure that that given targets are all Target instances)
    targets = [targets].flatten.map { |t| t.is_a?(String) ? Puppet::Pops::Types::TypeFactory.target.create(t) : t }
    if targets.empty?
      call_function('debug', "Simulating run_script of '#{found}' - no targets given - no action taken")
      Puppet::Pops::Types::ExecutionResult::EMPTY_RESULT
    else
      # Awaits change in the executor, enabling it receive Target instances
      hosts = targets.map { |h| h.host }

      Puppet::Pops::Types::ExecutionResult.from_bolt(
        executor.run_script(executor.from_uris(hosts), found, args_hash['arguments'])
      )
    end
  end
end
