require 'puppet/node'
require 'puppet/indirector/exec'

class Puppet::Node::Exec < Puppet::Indirector::Exec
    desc "Call an external program to get node information.  See
    the `ExternalNodes`:trac: page for more information."
    include Puppet::Util

    def command
        command = Puppet[:external_nodes]
        unless command != "none"
            raise ArgumentError, "You must set the 'external_nodes' parameter to use the external node terminus"
        end
        command.split
    end

    # Look for external node definitions.
    def find(name)
        output = super or return nil

        # Translate the output to ruby.
        result = translate(name, output)

        return create_node(name, result)
    end

    # Use the version of the facts, since we assume that's the main thing
    # that changes.  If someone wants their own way of defining version,
    # they can easily provide their own, um, version of this class.
    def version(name)
        Puppet::Node::Facts.version(name)
    end

    private

    # Turn our outputted objects into a Puppet::Node instance.
    def create_node(name, result)
        node = Puppet::Node.new(name)
        set = false
        [:parameters, :classes, :environment].each do |param|
            if value = result[param]
                node.send(param.to_s + "=", value)
                set = true
            end
        end

        node.fact_merge
        return node
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
