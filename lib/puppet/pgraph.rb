#  Created by Luke A. Kanies on 2006-11-24.
#  Copyright (c) 2006. All rights reserved.

require 'puppet/relationship'
require 'puppet/simple_graph'

# This class subclasses a graph class in order to handle relationships
# among resources.
class Puppet::PGraph < Puppet::SimpleGraph
    include Puppet::Util

    def add_edge(*args)
        @reversal = nil
        super
    end

    def add_vertex(*args)
        @reversal = nil
        super
    end

    # Which resources a given resource depends upon.
    def dependents(resource)
        tree_from_vertex(resource).keys
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
        @reversal.tree_from_vertex(resource, :out).keys
    end
    
    # Determine all of the leaf nodes below a given vertex.
    def leaves(vertex, direction = :out)
        tree = tree_from_vertex(vertex, direction)
        l = tree.keys.find_all { |c| adjacent(c, :direction => direction).empty? }
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
                edge.match?(event.name)
            end
        end.compact.flatten
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

                        add_edge(s, t, edge.label)
                    end

                    # Now get rid of the edge, so remove_vertex! works correctly.
                    remove_edge!(edge)
                end
            end
            remove_vertex!(container)
        end
    end

    # A different way of walking a tree, and a much faster way than the
    # one that comes with GRATR.
    def tree_from_vertex(start, direction = :out)
        predecessor={}
        walk(start, direction) do |parent, child|
            predecessor[child] = parent
        end
        predecessor       
    end
end
