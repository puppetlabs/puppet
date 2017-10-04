# Uploads the given file or directory to the given set of nodes and returns the result from each upload.
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
Puppet::Functions.create_function(:file_upload, Puppet::Functions::InternalFunction) do
  local_types do
    type 'NodeOrNodes = Variant[String[1], Array[NodeOrNodes]]'
  end

  dispatch :file_upload do
    scope_param
    param 'String[1]', :source
    param 'String[1]', :destination
    repeated_param 'NodeOrNodes', :nodes
  end

  def file_upload(scope, source, destination, *nodes)
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(
        Puppet::Pops::Issues::TASK_OPERATION_NOT_SUPPORTED_WHEN_COMPILING,
        {:operation => 'file_upload'})
    end

    unless Puppet.features.bolt?
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(Puppet::Pops::Issues::TASK_MISSING_BOLT, :action => _('do file uploads'))
    end

    found = Puppet::Parser::Files.find_file(source, scope.compiler.environment)
    unless found && Puppet::FileSystem.exist?(found)
      raise Puppet::ParseErrorWithIssue.from_issue_and_stack(Puppet::Pops::Issues::NO_SUCH_FILE_OR_DIRECTORY, {:file => source})
    end

    hosts = nodes.flatten
    if hosts.empty?
      call_function('debug', "Simulating file upload of '#{found}' - no hosts given - no action taken")
      Puppet::Pops::Types::ExecutionResult::EMPTY_RESULT
    else
      Puppet::Pops::Types::ExecutionResult.from_bolt(Bolt::Executor.from_uris(hosts).file_upload(found, destination))
    end
  end
end
