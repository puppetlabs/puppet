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
        return output
    end

    private

    # Proxy the execution, so it's easier to test.
    def execute(command)
        Puppet::Util.execute(command)
    end

    # Call the external command and see if it returns our output.
    def query(name)
        external_command = command

        # Make sure it's an arry
        unless external_command.is_a?(Array)
            raise Puppet::DevError, "Exec commands must be an array"
        end

        # Make sure it's fully qualified.
        unless external_command[0][0] == File::SEPARATOR[0]
            raise ArgumentError, "You must set the exec parameter to a fully qualified command"
        end

        # Add our name to it.
        external_command << name
        begin
            output = execute(external_command)
        rescue Puppet::ExecutionFailure => detail
            Puppet.err "Failed to find %s via exec: %s" % [name, detail]
            return nil
        end

        if output =~ /\A\s*\Z/ # all whitespace
            Puppet.debug "Empty response for %s from exec %s terminus" % [name, self.name]
            return nil
        else
            return output
        end
    end
end
