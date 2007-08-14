#  Created by Luke A. Kanies on 2007-08-13.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/util'
require 'puppet/util/classgen'
require 'puppet/util/instance_loader'

# Look up a node, along with all the details about it.
class Puppet::Network::Handler::Node < Puppet::Network::Handler
    # A simplistic class for managing the node information itself.
    class SimpleNode
        attr_accessor :name, :classes, :parameters, :environment

        def initialize(options)
            unless @name = options[:name]
                raise ArgumentError, "Nodes require names" unless self.name
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
        end
    end
    desc "Retrieve information about nodes."

    extend Puppet::Util::ClassGen
    extend Puppet::Util::InstanceLoader

    module SourceBase
        include Puppet::Util::Docs
    end

    @interface = XMLRPC::Service::Interface.new("nodes") { |iface|
        iface.add_method("string node(key)")
        iface.add_method("string parameters(key)")
        iface.add_method("string environment(key)")
        iface.add_method("string classes(key)")
    }

    # Set up autoloading and retrieving of reports.
    autoload :node_source, 'puppet/node_source'

    # Add a new node source.
    def self.newnode_source(name, options = {}, &block)
        name = symbolize(name)

        genmodule(name, :extend => SourceBase, :hash => instance_hash(:node_source), :block => block)
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
        instance_hash(:node_source).delete(name)
    end

    # Return a given node's classes.
    def classes(key)
        raise "look up classes"
    end

    # Return a given node's environment.
    def environment(key)
        raise "look up environment"
        if node = node(key)
            node.environment
        else
            nil
        end
    end

    # Return an entire node configuration.
    def node(key)
        # Try to find our node...
        nodes = nodes.collect { |n| n.to_s.downcase }

        method = "nodesearch_%s" % @nodesource
        # Do an inverse sort on the length, so the longest match always
        # wins
        nodes.sort { |a,b| b.length <=> a.length }.each do |node|
            node = node.to_s if node.is_a?(Symbol)
            if obj = self.send(method, node)
                if obj.is_a?(AST::Node)
                    nsource = obj.file
                else
                    nsource = obj.source
                end
                Puppet.info "Found %s in %s" % [node, nsource]
                return obj
            end
        end

        # If they made it this far, we haven't found anything, so look for a
        # default node.
        unless nodes.include?("default")
            if defobj = self.nodesearch("default")
                Puppet.notice "Using default node for %s" % [nodes[0]]
                return defobj
            end
        end

        return nil
    end

    def parameters(key)
        raise "Look up parameters"
    end

    private
    def node_facts(key)
        raise "Look up node facts"
    end

    def node_names(key, facts = nil)
        facts ||= node_facts(key)
        raise "Calculate node names"
    end
end
