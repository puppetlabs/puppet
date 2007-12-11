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

    # Retrieve a node from the node source, with some additional munging
    # thrown in for kicks.
    def self.find_by_any_name(key)
        return nil unless key

        facts = node_facts(key)
        node = nil
        names = node_names(key, facts)
        names.each do |name|
            name = name.to_s if name.is_a?(Symbol)
            break if node = find(name)
        end

        # If they made it this far, we haven't found anything, so look for a
        # default node.
        unless node or names.include?("default")
            if node = find("default")
                Puppet.notice "Using default node for %s" % key
            end
        end

        if node
            node.names = names

            return node
        else
            return nil
        end
    end

    private

    # Look up the node facts so we can generate the node names to use.
    def self.node_facts(key)
        if facts = Puppet::Node::Facts.find(key)
            facts.values
        else
            {}
        end
    end

    # Calculate the list of node names we should use for looking
    # up our node.
    def self.node_names(key, facts = nil)
        facts ||= node_facts(key)
        names = []

        if hostname = facts["hostname"]
            unless hostname == key
                names << hostname
            end
        else
            hostname = key
        end

        if fqdn = facts["fqdn"]
            hostname = fqdn
            names << fqdn
        end

        # Make sure both the fqdn and the short name of the
        # host can be used in the manifest
        if hostname =~ /\./
            names << hostname.sub(/\..+/,'')
        elsif domain = facts['domain']
            names << hostname + "." + domain
        end

        # Sort the names inversely by name length.
        names.sort! { |a,b| b.length <=> a.length }

        # And make sure the key is first, since that's the most
        # likely usage.
        ([key] + names).uniq
    end

    public

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
