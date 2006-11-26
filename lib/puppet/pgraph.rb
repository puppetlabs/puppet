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
    # Collect all of the targets for the list of events.  Basically just iterates
    # over the sources of the events and returns all of the targets of them.
    def collect_targets(events)
        events.collect do |event|
            source = event.source
            start = source
            
            # Get all of the edges that this vertex points at
            adjacent(source, :direction => :out, :type => :edges).find_all do |edge|
                edge.match?(event.event)
            end.collect { |event|
                target = event.target
                if target.respond_to?(:ref)
                    source.info "Scheduling %s of %s" %
                        [event.callback, target.ref]
                end
                target
            }
        end.flatten
    end
    
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
            adjacent(vertex, :direction => :in).each do |up|
                leaves.each do |leaf|
                    add_edge!(up, leaf)
                    if cyclic?
                        raise ArgumentError,
                            "%s => %s results in a loop" %
                            [up, leaf]
                    end
                end
            end
            
            # Then for each of the out edges
            adjacent(vertex, :direction => :out).each do |down|
                leaves.each do |leaf|
                    add_edge!(leaf, down)
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

    # Trigger any subscriptions to a child.  This does an upwardly recursive
    # search -- it triggers the passed object, but also the object's parent
    # and so on up the tree.
    def trigger(child)
        obj = child
        callbacks = Hash.new { |hash, key| hash[key] = [] }
        sources = Hash.new { |hash, key| hash[key] = [] }

        trigged = []
        while obj
            if @targets.include?(obj)
                callbacks.clear
                sources.clear
                @targets[obj].each do |event, sub|
                    # Collect all of the subs for each callback
                    callbacks[sub.callback] << sub

                    # And collect the sources for logging
                    sources[event.source] << sub.callback
                end

                sources.each do |source, callbacklist|
                    obj.debug "%s[%s] results in triggering %s" %
                        [source.class.name, source.name, callbacklist.join(", ")]
                end

                callbacks.each do |callback, subs|
                    message = "Triggering '%s' from %s dependencies" %
                        [callback, subs.length]
                    obj.notice message
                    # At this point, just log failures, don't try to react
                    # to them in any way.
                    begin
                        obj.send(callback)
                        @resourcemetrics[:restarted] += 1
                    rescue => detail
                        obj.err "Failed to call %s on %s: %s" %
                            [callback, obj, detail]

                        @resourcemetrics[:failed_restarts] += 1

                        if Puppet[:debug]
                            puts detail.backtrace
                        end
                    end

                    # And then add an event for it.
                    trigged << Puppet::Event.new(
                        :event => :triggered,
                        :transaction => self,
                        :source => obj,
                        :message => message
                    )

                    triggered(obj, callback)
                end
            end

            obj = obj.parent
        end

        if trigged.empty?
            return nil
        else
            return trigged
        end
    end
    
    def to_jpg(name)
        gv = vertices()
        Dir.chdir("/Users/luke/Desktop/pics") do
            induced_subgraph(gv).write_to_graphic_file('jpg', name)
        end
    end
end

# $Id$
