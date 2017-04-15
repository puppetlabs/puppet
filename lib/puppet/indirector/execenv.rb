require 'puppet/indirector/terminus'
require 'puppet/util'

class Puppet::Indirector::Execenv < Puppet::Indirector::Terminus
  # Look for external node definitions.
  def find(request)
    name = request.key
    external_command = command

    # Make sure it's an array
    raise Puppet::DevError, "Exec commands must be an array" unless external_command.is_a?(Array)

    # Make sure it's fully qualified.
    raise ArgumentError, "You must set the exec parameter to a fully qualified command" unless Puppet::Util.absolute_path?(external_command[0])

    # Add our name (FQDN) to the command
    command << request.key

    # Add the agent environment to the command
    command << request.environment.name

    begin
      output = execute(external_command, :failonfail => true, :combine => false)
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Failed to find #{name} via exec: #{detail}"
    end

    if output =~ /\A\s*\Z/ # all whitespace
      Puppet.debug "Empty response for #{name} from #{self.name} terminus"
      return nil
    else
      return output
    end
  end

  private

  # Proxy the execution, so it's easier to test.
  def execute(command, arguments)
    Puppet::Util::Execution.execute(command,arguments)
  end

end

