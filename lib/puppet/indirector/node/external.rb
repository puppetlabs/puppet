require 'puppet/node/facts'

Puppet::Indirector.register_terminus :node, :external do
    desc "Call an external program to get node information."

    include Puppet::Util

    # Proxy the execution, so it's easier to test.
    def execute(command)
        Puppet::Util.execute(command)
    end

    # Look for external node definitions.
    def get(name)
        unless Puppet[:external_nodes] != "none"
            raise ArgumentError, "You must set the 'external_nodes' parameter to use the external node source"
        end
  
        unless Puppet[:external_nodes][0] == File::SEPARATOR[0]
            raise ArgumentError, "You must set the 'external_nodes' parameter to a fully qualified command"
        end

        # Run the command.
        unless output = query(name)
            return nil
        end

        # Translate the output to ruby.
        result = translate(name, output)

        return create_node(name, result)
    end

    private

    # Turn our outputted objects into a Puppet::Node instance.
    def create_node(name, result)
        node = Puppet::Node.new(name)
        set = false
        [:parameters, :classes].each do |param|
            if value = result[param]
                node.send(param.to_s + "=", value)
                set = true
            end
        end

        if set
            node.fact_merge
            return node
        else
            return nil
        end
    end

    # Call the external command and see if it returns our output.
    def query(name)
        # This is a very cheap way to do this, since it will break on
        # commands that have spaces in the arguments.  But it's good
        # enough for most cases.
        external_node_command = Puppet[:external_nodes].split
        external_node_command << name
        begin
            output = execute(external_node_command)
        rescue Puppet::ExecutionFailure => detail
            if $?.exitstatus == 1
                return nil
            else
                Puppet.err "Could not retrieve external node information for %s: %s" % [name, detail]
            end
            return nil
        end
        
        if output =~ /\A\s*\Z/ # all whitespace
            Puppet.debug "Empty response for %s from external node source" % name
            return nil
        else
            return output
        end
    end

    # Translate the yaml string into Ruby objects.
    def translate(name, output)
        begin
            YAML.load(output).inject({}) { |hash, data| hash[symbolize(data[0])] = data[1]; hash }
        rescue => detail
            raise Puppet::Error, "Could not load external node results for %s: %s" % [name, detail]
        end
    end
end
