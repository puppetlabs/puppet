# A simplistic class for managing the node information itself.
class Puppet::Node
    # Set up indirection, so that nodes can be looked for in
    # the node sources.
    require 'puppet/indirector'
    extend Puppet::Indirector

    # Use the node source as the indirection terminus.
    indirects :node, :to => :node_source

    # Retrieve a node from the node source, with some additional munging
    # thrown in for kicks.
    # LAK:FIXME Crap.  This won't work, because we might have two copies of this class,
    # one remote and one local, and we won't know which one should do all of the
    # extra crap.
    def self.get(key)
        return nil unless key
        if node = cached?(key)
            return node
        end
        facts = node_facts(key)
        node = nil
        names = node_names(key, facts)
        names.each do |name|
            name = name.to_s if name.is_a?(Symbol)
            if node = nodesearch(name) and @source != "none"
                Puppet.info "Found %s in %s" % [name, @source]
                break
            end
        end

        # If they made it this far, we haven't found anything, so look for a
        # default node.
        unless node or names.include?("default")
            if node = nodesearch("default")
                Puppet.notice "Using default node for %s" % key
            end
        end

        if node
            node.source = @source
            node.names = names

            # Merge the facts into the parameters.
            if fact_merge?
                node.fact_merge(facts)
            end

            cache(node)

            return node
        else
            return nil
        end
    end

    private

    # Store the node to make things a bit faster.
    def self.cache(node)
        @node_cache[node.name] = node
    end

    # If the node is cached, return it.
    def self.cached?(name)
        # Don't use cache when the filetimeout is set to 0
        return false if [0, "0"].include?(Puppet[:filetimeout])

        if node = @node_cache[name] and Time.now - node.time < Puppet[:filetimeout]
            return node
        else
            return false
        end
    end

    # Look up the node facts from our fact handler.
    def self.node_facts(key)
        if facts = Puppet::Node::Facts.get(key)
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
    attr_writer :environment

    # Do not return environments that are the empty string, and use
    # explicitly set environments, then facts, then a central env
    # value.
    def environment
        unless @environment and @environment != ""
            if env = parameters["environment"] and env != ""
                @environment = env
            elsif env = Puppet[:environment] and env != ""
                @environment = env
            else
                @environment = nil
            end
        end
        @environment
    end

    def initialize(name, options = {})
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

        @environment = options[:environment] 

        @time = Time.now
    end

    # Merge the node facts with parameters from the node source.
    # This is only called if the node source has 'fact_merge' set to true.
    def fact_merge(facts)
        facts.each do |name, value|
            @parameters[name] = value unless @parameters.include?(name)
        end
    end
end
