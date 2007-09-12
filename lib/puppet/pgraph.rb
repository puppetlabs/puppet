#  Created by Luke A. Kanies on 2006-11-24.
#  Copyright (c) 2006. All rights reserved.

require 'puppet/external/gratr/digraph'
require 'puppet/external/gratr/import'
require 'puppet/external/gratr/dot'
require 'puppet/relationship'

# This class subclasses a graph class in order to handle relationships
# among resources.
class Puppet::PGraph < GRATR::Digraph
    # This is the type used for splicing.
    attr_accessor :container_type

    include Puppet::Util

    def add_edge!(*args)
        @reversal = nil
        super
    end

    # Add a resource to our graph and to our resource table.
    def add_resource(resource)
        unless resource.respond_to?(:ref)
            raise ArgumentError, "Can only add objects that respond to :ref"
        end

        ref = resource.ref
        if @resource_table.include?(ref)
            raise ArgumentError, "Resource %s is already defined" % ref
        else
            @resource_table[ref] = resource
        end
    end

    def add_vertex!(*args)
        @reversal = nil
        super
    end
    
    def clear
        @vertex_dict.clear
        #@resource_table.clear
        if defined? @edge_number
            @edge_number.clear
        end
    end

    # Make sure whichever edge has a label keeps the label
    def copy_label(source, target, label)
        # 'require' relationships will not have a label,
        # and all 'subscribe' relationships have the same
        # label, at least for now.

        # Labels default to {}, so we can't just test for nil.
        newlabel = label || {}
        oldlabel = edge_label(source, target) || {}
        if ! newlabel.empty? and oldlabel.empty?
            edge_label_set(source, target, label)
            # We should probably check to see if the labels both exist
            # and don't match, but we'd just throw an error which the user
            # couldn't do anyting about.
        end
    end

    # Which resources a given resource depends upon.
    def dependents(resource)
        tree_from_vertex2(resource).keys
    end
    
    # Which resources depend upon the given resource.
    def dependencies(resource)
        # Cache the reversal graph, because it's somewhat expensive
        # to create.
        unless defined? @reversal and @reversal
            @reversal = reversal
        end
        # Strangely, it's significantly faster to search a reversed
        # tree in the :out direction than to search a normal tree
        # in the :in direction.
        @reversal.tree_from_vertex2(resource, :out).keys
        #tree_from_vertex2(resource, :in).keys
    end
    
    # Override this method to use our class instead.
    def edge_class()
        Puppet::Relationship
    end

    def initialize(*args)
        super
        # Create a table to keep references to all of our resources.
        @resource_table = {}
    end
    
    # Determine all of the leaf nodes below a given vertex.
    def leaves(vertex, type = :dfs)
        tree = tree_from_vertex(vertex, type)
        l = tree.keys.find_all { |c| adjacent(c, :direction => :out).empty? }
        return l
    end
    
    # Collect all of the edges that the passed events match.  Returns
    # an array of edges.
    def matching_edges(events, base = nil)
        events.collect do |event|
            source = base || event.source
            
            unless vertex?(source)
                Puppet.warning "Got an event from invalid vertex %s" % source.ref
                next
            end
            # Get all of the edges that this vertex should forward events
            # to, which is the same thing as saying all edges directly below
            # This vertex in the graph.
            adjacent(source, :direction => :out, :type => :edges).find_all do |edge|
                edge.match?(event.event)
            end
        end.flatten
    end

    # Look a resource up by its reference (e.g., File["/etc/passwd"]).
    def resource(ref)
        @resource_table[ref]
    end
    
    # Take container information from another graph and use it
    # to replace any container vertices with their respective leaves.
    # This creates direct relationships where there were previously
    # indirect relationships through the containers. 
    def splice!(other, type)
        # We have to get the container list via a topological sort on the
        # configuration graph, because otherwise containers that contain
        # other containers will add those containers back into the
        # graph.  We could get a similar affect by only setting relationships
        # to container leaves, but that would result in many more
        # relationships.
        containers = other.topsort.find_all { |v| v.is_a?(type) and vertex?(v) }
        containers.each do |container|
            # Get the list of children from the other graph.
            children = other.adjacent(container, :direction => :out)

            # Just remove the container if it's empty.
            if children.empty?
                remove_vertex!(container)
                next
            end
            
            # First create new edges for each of the :in edges
            [:in, :out].each do |dir|
                edges = adjacent(container, :direction => dir, :type => :edges)
                edges.each do |edge|
                    children.each do |child|
                        if dir == :in
                            s = edge.source
                            t = child
                        else
                            s = child
                            t = edge.target
                        end

                        # We don't want to add multiple copies of the
                        # same edge, but we *do* want to make sure we
                        # keep labels around.
                        # XXX This will *not* work when we support multiple
                        # types of labels, and only works now because
                        # you can only do simple subscriptions.
                        if edge?(s, t)
                            copy_label(s, t, edge.label)
                            next
                        end
                        add_edge!(s, t, edge.label)
                    end

                    # Now get rid of the edge, so remove_vertex! works correctly.
                    remove_edge!(edge)
                    Puppet.debug "%s: %s => %s: %s" % [container,
                        edge.source, edge.target, edge?(edge)]
                end
            end
            remove_vertex!(container)
        end
    end
    
    # For some reason, unconnected vertices do not show up in
    # this graph.
    def to_jpg(path, name)
        gv = vertices()
        Dir.chdir(path) do
            induced_subgraph(gv).write_to_graphic_file('jpg', name)
        end
    end

    # Replace the default method, because we want to throw errors on back edges,
    # not just skip them.
    def topsort(start = nil, &block)
        result  = []
        go      = true 
        cycles = []
        back    = Proc.new { |e|
            cycles << e
            go = false
        }
        push    = Proc.new { |v| result.unshift(v) if go}
        start   ||= vertices[0]
        dfs({:exit_vertex => push, :back_edge => back, :start => start})
        if block_given?
            result.each {|v| yield(v) }
        end

        if cycles.length > 0
            msg = "Found cycles in the following relationships:"
            cycles.each { |edge| msg += " %s => %s" % [edge.source, edge.target] }
            raise Puppet::Error, msg
        end
        return result
    end

    # A different way of walking a tree, and a much faster way than the
    # one that comes with GRATR.
    def tree_from_vertex2(start, direction = :out)
        predecessor={}
        walk(start, direction) do |parent, child|
            predecessor[child] = parent
        end
        predecessor       
    end

    # A support method for tree_from_vertex2.  Just walk the tree and pass
    # the parents and children.
    def walk(source, direction, &block)
        adjacent(source, :direction => direction).each do |target|
            yield source, target
            walk(target, direction, &block)
        end
    end
end
