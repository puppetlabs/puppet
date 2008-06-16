require 'puppet/indirector'

# A class for managing nodes, including their facts and environment.
class Puppet::Node
    require 'puppet/node/facts'
    require 'puppet/node/environment'

    # Set up indirection, so that nodes can be looked for in
    # the node sources.
    extend Puppet::Indirector

    # Use the node source as the indirection terminus.
    indirects :node, :terminus_setting => :node_terminus, :doc => "Where to find node information.
        A node is composed of its name, its facts, and its environment."

    attr_accessor :name, :classes, :parameters, :source, :ipaddress
    attr_reader :time

    # Set the environment, making sure that it's valid.
    def environment=(value)
        raise(ArgumentError, "Invalid environment %s" % value) unless Puppet::Node::Environment.valid?(value)
        @environment = value
    end

    # Do not return environments that are the empty string, and use
    # explicitly set environments, then facts, then a central env
    # value.
    def environment
        unless @environment
            if env = parameters["environment"]
                raise(ArgumentError, "Invalid environment %s from parameters" % env) unless Puppet::Node::Environment.valid?(env)
                @environment = env
            else
                @environment = Puppet::Node::Environment.new.name.to_s
            end
        end
        @environment
    end

    def initialize(name, options = {})
        unless name
            raise ArgumentError, "Node names cannot be nil"
        end
        @name = name

        # Provide a default value.
        if names = options[:names]
            if names.is_a?(String)
                @names = [names]
            else
                @names = names
            end
        else
            @names = [name]
        end

        if classes = options[:classes]
            if classes.is_a?(String)
                @classes = [classes]
            else
                @classes = classes
            end
        else
            @classes = []
        end

        @parameters = options[:parameters] || {}

        self.environment = options[:environment] if options[:environment]

        @time = Time.now
    end

    # Merge the node facts with parameters from the node source.
    def fact_merge
        if facts = Puppet::Node::Facts.find(name)
            merge(facts.values)
        end
    end

    # Merge any random parameters into our parameter list.
    def merge(params)
        params.each do |name, value|
            @parameters[name] = value unless @parameters.include?(name)
        end

        @parameters["environment"] ||= self.environment if self.environment
    end

    # Calculate the list of names we might use for looking
    # up our node.  This is only used for AST nodes.
    def names
        names = []

        # First, get the fqdn
        unless fqdn = parameters["fqdn"]
            if domain = parameters["domain"]
                fqdn = parameters["hostname"] + "." + parameters["domain"]
            end
        end

        # Now that we (might) have the fqdn, add each piece to the name
        # list to search, in order of longest to shortest.
        if fqdn
            list = fqdn.split(".")
            tmp = []
            list.each_with_index do |short, i|
                tmp << list[0..i].join(".")
            end
            names += tmp.reverse
        end

        # And make sure the node name is first, since that's the most
        # likely usage.
        #   The name is usually the Certificate CN, but it can be
        # set to the 'facter' hostname instead.
        if Puppet[:node_name] == 'cert'
            names.unshift name
        else
            names.unshift parameters["hostname"]
        end
        names.uniq
    end
end
