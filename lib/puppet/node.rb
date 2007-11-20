require 'puppet/indirector'

# A simplistic class for managing the node information itself.
class Puppet::Node
    require 'puppet/node/facts'
    require 'puppet/node/environment'

    # Set up indirection, so that nodes can be looked for in
    # the node sources.
    extend Puppet::Indirector

    # Use the node source as the indirection terminus.
    indirects :node, :terminus_class => :null

    # Add the node-searching methods.  This is what people will actually
    # interact with that will find the node with the list of names or
    # will search for a default node.
    require 'puppet/node/searching'
    extend Puppet::Node::Searching

    attr_accessor :name, :classes, :parameters, :source, :ipaddress, :names
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
    end
end
