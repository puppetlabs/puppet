#  Created by Luke A. Kanies on 2007-08-13.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/util'
require 'puppet/util/classgen'
require 'puppet/util/instance_loader'

# Look up a node, along with all the details about it.
class Puppet::Network::Handler::Node < Puppet::Network::Handler
    # A simplistic class for managing the node information itself.
    class SimpleNode
        attr_accessor :name, :classes, :parameters, :environment, :source, :ipaddress, :names
        attr_reader :time

        def initialize(name, options = {})
            @name = name

            # Provide a default value.
            @names = [name]

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

            unless @environment = options[:environment] 
                if env = Puppet[:environment] and env != ""
                    @environment = env
                end
            end

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

    desc "Retrieve information about nodes."

    extend Puppet::Util::ClassGen
    extend Puppet::Util::InstanceLoader

    # A simple base module we can use for modifying how our node sources work.
    module SourceBase
        include Puppet::Util::Docs
    end

    @interface = XMLRPC::Service::Interface.new("nodes") { |iface|
        iface.add_method("string details(key)")
        iface.add_method("string parameters(key)")
        iface.add_method("string environment(key)")
        iface.add_method("string classes(key)")
    }

    # Set up autoloading and retrieving of reports.
    autoload :node_source, 'puppet/node_source'

    attr_reader :source

    # Add a new node source.
    def self.newnode_source(name, options = {}, &block)
        name = symbolize(name)

        fact_merge = options[:fact_merge]
        mod = genmodule(name, :extend => SourceBase, :hash => instance_hash(:node_source), :block => block)
        mod.send(:define_method, :fact_merge?) do
            fact_merge
        end
        mod
    end

    # Collect the docs for all of our node sources.
    def self.node_source_docs
        docs = ""

        # Use this method so they all get loaded
        instance_loader(:node_source).loadall
        loaded_instances(:node_source).sort { |a,b| a.to_s <=> b.to_s }.each do |name|
            mod = self.node_source(name)
            docs += "%s\n%s\n" % [name, "-" * name.to_s.length]

            docs += Puppet::Util::Docs.scrub(mod.doc) + "\n\n"
        end

        docs
    end

    # List each of the node sources.
    def self.node_sources
        instance_loader(:node_source).loadall
        loaded_instances(:node_source)
    end

    # Remove a defined node source; basically only used for testing.
    def self.rm_node_source(name)
        rmclass(name, :hash => instance_hash(:node_source))
    end

    # Return a given node's classes.
    def classes(key)
        if node = details(key)
            node.classes
        else
            nil
        end
    end

    # Return an entire node configuration.  This uses the 'nodesearch' method
    # defined in the node_source to look for the node.
    def details(key, client = nil, clientip = nil)
        facts = node_facts(key)
        node = nil
        names = node_names(key, facts)
        names.each do |name|
            name = name.to_s if name.is_a?(Symbol)
            if node = nodesearch(name)
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
            return node
        else
            return nil
        end
    end

    # Return a given node's environment.
    def environment(key, client = nil, clientip = nil)
        if node = details(key)
            node.environment
        else
            nil
        end
    end

    # Create our node lookup tool.
    def initialize(hash = {})
        @source = hash[:Source] || Puppet[:node_source]

        unless mod = self.class.node_source(@source)
            raise ArgumentError, "Unknown node source '%s'" % @source
        end

        extend(mod)

        super

        # We cache node info for speed
        @node_cache = {}
    end

    # Try to retrieve a given node's parameters.
    def parameters(key, client = nil, clientip = nil)
        if node = details(key)
            node.parameters
        else
            nil
        end
    end

    private

    # Store the node to make things a bit faster.
    def cache(node)
        @node_cache[node.name] = node
    end

    # If the node is cached, return it.
    def cached?(name)
        # Don't use cache when the filetimeout is set to 0
        return false if [0, "0"].include?(Puppet[:filetimeout])

        if node = @node_cache[name] and Time.now - node.time < Puppet[:filetimeout]
            return node
        else
            return false
        end
    end

    # Create/cache a fact handler.
    def fact_handler
        unless defined?(@fact_handler)
            @fact_handler = Puppet::Network::Handler.handler(:facts).new
        end
        @fact_handler
    end

    # Short-hand for creating a new node, so the node sources don't need to
    # specify the constant.
    def newnode(options)
        SimpleNode.new(options)
    end

    # Look up the node facts from our fact handler.
    def node_facts(key)
        if facts = fact_handler.get(key)
            facts
        else
            {}
        end
    end

    # Calculate the list of node names we should use for looking
    # up our node.
    def node_names(key, facts = nil)
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
end
