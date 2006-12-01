#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2006-11-24.
#  Copyright (c) 2006. All rights reserved.

require 'puppet/gratr/digraph'
require 'puppet/gratr/import'
require 'puppet/gratr/dot'
require 'puppet/relationship'

# This class subclasses a graph class in order to handle relationships
# among resources.
class Puppet::PGraph < GRATR::Digraph
    # The dependencies for a given resource.
    def dependencies(resource)
        tree_from_vertex(resource, :dfs).keys
    end
    
    # Override this method to use our class instead.
    def edge_class()
        Puppet::Relationship
    end
    
    # Determine all of the leaf nodes below a given vertex.
    def leaves(vertex, type = :dfs)
        tree = tree_from_vertex(vertex, type)
        leaves = tree.keys.find_all { |c| adjacent(c, :direction => :out).empty? }
        return leaves
    end
    
    # Collect all of the edges that the passed events match.  Returns
    # an array of edges.
    def matching_edges(events)
        events.collect do |event|
            source = event.source
            
            unless vertex?(source)
                Puppet.warning "Got an event from invalid vertex %s" % source.ref
                next
            end
            
            # Get all of the edges that this vertex should forward events
            # to, which is the same thing as saying all edges directly below
            # This vertex in the graph.
            adjacent(source, :direction => :out, :type => :edges).find_all do |edge|
                edge.match?(event.event)
            end.each { |edge|
                target = edge.target
                if target.respond_to?(:ref)
                    source.info "Scheduling %s of %s" %
                        [edge.callback, target.ref]
                end
            }
        end.flatten
    end
    
    # Take container information from another graph and use it
    # to replace any container vertices with their respective leaves.
    # This creates direct relationships where there were previously
    # indirect relationships through the containers. 
    def splice!(other, type)
        vertices.each do |vertex|
            # Go through each vertex and replace the edges with edges
            # to the leaves instead
            next unless vertex.is_a?(type)
            
            leaves = other.leaves(vertex)
            next if leaves.empty?
            
            # First create new edges for each of the :in edges
            adjacent(vertex, :direction => :in, :type => :edges).each do |edge|
                leaves.each do |leaf|
                    add_edge!(edge.source, leaf, edge.label)
                    if cyclic?
                        raise ArgumentError,
                            "%s => %s results in a loop" %
                            [up, leaf]
                    end
                end
            end
            
            # Then for each of the out edges
            adjacent(vertex, :direction => :out, :type => :edges).each do |edge|
                leaves.each do |leaf|
                    add_edge!(leaf, edge.target, edge.label)
                    if cyclic?
                        raise ArgumentError,
                            "%s => %s results in a loop" %
                            [leaf, down]
                    end
                end
            end
            
            # And finally, remove the vertex entirely.
            remove_vertex!(vertex)
        end
    end
    
    # For some reason, unconnected vertices do not show up in
    # this graph.
    def to_jpg(name)
        gv = vertices()
        Dir.chdir("/Users/luke/Desktop/pics") do
            induced_subgraph(gv).write_to_graphic_file('jpg', name)
        end
    end
end

# $Id$
