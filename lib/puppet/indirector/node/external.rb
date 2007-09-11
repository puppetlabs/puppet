Puppet::Indirector.register_terminus :node, :external, :fact_merge => true do
    desc "Call an external program to get node information."

    include Puppet::Util
    # Look for external node definitions.
    def get(name)
        return nil unless Puppet[:external_nodes] != "none"
  
        # This is a very cheap way to do this, since it will break on
        # commands that have spaces in the arguments.  But it's good
        # enough for most cases.
        external_node_command = Puppet[:external_nodes].split
        external_node_command << name
        begin
            output = Puppet::Util.execute(external_node_command)
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
        end

        begin
            result = YAML.load(output).inject({}) { |hash, data| hash[symbolize(data[0])] = data[1]; hash }
        rescue => detail
            raise Puppet::Error, "Could not load external node results for %s: %s" % [name, detail]
        end

        node = newnode(name)
        set = false
        [:parameters, :classes].each do |param|
            if value = result[param]
                node.send(param.to_s + "=", value)
                set = true
            end
        end

        if set
            return node
        else
            return nil
        end
    end
end
