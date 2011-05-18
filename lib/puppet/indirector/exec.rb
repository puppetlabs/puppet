require 'puppet/indirector/terminus'
require 'puppet/util'

class Puppet::Indirector::Exec < Puppet::Indirector::Terminus
  # Look for external node definitions.
  def find(request)
    # Run the command.
    unless output = query(request.key)
      return nil
    end

    # Translate the output to ruby.
    output
  end

  private

  # Proxy the execution, so it's easier to test.
  def execute(command, arguments)
    Puppet::Util.execute(command,arguments)
  end

  # Call the external command and see if it returns our output.
  def query(name)
    external_command = command

    # Make sure it's an arry
    raise Puppet::DevError, "Exec commands must be an array" unless external_command.is_a?(Array)

    # Make sure it's fully qualified.
    raise ArgumentError, "You must set the exec parameter to a fully qualified command" unless external_command[0][0] == File::SEPARATOR[0]

    # Add our name to it.
    external_command << name
    begin
      output = execute(external_command, :combine => false)
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Failed to find #{name} via exec: #{detail}"
    end

    if output =~ /\A\s*\Z/ # all whitespace
      Puppet.debug "Empty response for #{name} from exec #{self.name} terminus"
      return nil
    else
      return output
    end
  end
end
