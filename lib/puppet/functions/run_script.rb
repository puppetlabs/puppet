# Uploads the given script to the given set of nodes and returns the result of having each node execute the script.
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
Puppet::Functions.create_function(:run_script, Puppet::Functions::InternalFunction) do
  local_types do
    type 'NodeOrNodes = Variant[String[1], Array[NodeOrNodes]]'
  end

  dispatch :run_script do
    scope_param
    param 'String[1]', :script
    repeated_param 'NodeOrNodes', :nodes
  end

  def run_script(scope, script, *nodes)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
        {:operation => 'run_script'})
    end

    unless Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(Puppet::Pops::Issues::TASK_MISSING_BOLT, :action => _('run a script'))
    end

    found = Puppet::Parser::Files.find_file(script, scope.compiler.environment)
    unless found && Puppet::FileSystem.exist?(found)
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(Puppet::Pops::Issues::NO_SUCH_FILE_OR_DIRECTORY, {:file => script})
    end
    unless Puppet::FileSystem.file?(found)
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(Puppet::Pops::Issues::NOT_A_FILE, {:file => script})
    end

    hosts = nodes.flatten
    if hosts.empty?
      call_function('debug', "Simulating run_script of '#{found}' - no hosts given - no action taken")
      Puppet::Pops::Types::ExecutionResult::EMPTY_RESULT
    else
      Puppet::Pops::Types::ExecutionResult.from_bolt(Bolt::Executor.from_uris(hosts).run_script(found))
    end
  end
end
