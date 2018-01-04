require 'puppet/indirector/terminus'
require 'puppet/util'

class Puppet::Indirector::Exec < Puppet::Indirector::Terminus
  # Look for external node definitions.
  def find(request)
    name = request.key
    external_command = command

    # Make sure it's an array
    raise Puppet::DevError, _("Exec commands must be an array") unless external_command.is_a?(Array)

    # Make sure it's fully qualified.
    raise ArgumentError, _("You must set the exec parameter to a fully qualified command") unless Puppet::Util.absolute_path?(external_command[0])

    # Add our name to it.
    external_command << name
    begin
      output = execute(external_command, :failonfail => true, :combine => false)
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, _("Failed to find %{name} via exec: %{detail}") % { name: name, detail: detail }, detail.backtrace
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
