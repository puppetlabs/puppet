#  Created by Luke Kanies on 2006-11-16.
#  Copyright (c) 2006. All rights reserved.

require 'puppet'
require 'puppet/gratr/digraph'
require 'puppet/gratr/import'
require 'puppet/gratr/dot'

class GRATR::Digraph
    # Determine all of the leaf nodes below a given vertex.
    def leaves(vertex, type = :dfs)
        tree = tree_from_vertex(vertex, type)
        leaves = tree.keys.find_all { |c| adjacent(c, :direction => :out).empty? }
        return leaves
    end
end

# A module that handles the small amount of graph stuff in Puppet.
module Puppet::Util::Graph
    # Make a graph where each of our children gets converted to
    # the receiving end of an edge.  Call the same thing on all
    # of our children, optionally using a block
    def to_graph(graph = nil, &block)
        # Allow our calling function to send in a graph, so that we
        # can call this recursively with one graph.
        graph ||= GRATR::Digraph.new
        
        self.each do |child|
            unless block_given? and ! yield(child)
                graph.add_edge!(self, child)

                if graph.cyclic?
                    raise Puppet::Error, "%s created a cyclic graph" % self
                end
                
                if child.respond_to?(:to_graph)
                    child.to_graph(graph, &block)
                end
            end
        end
        
        if graph.cyclic?
            raise Puppet::Error, "%s created a cyclic graph" % self
        end
        
        graph
    end
    
    def to_jpg(graph = nil)
        graph ||= to_graph
        gv = graph.vertices
        Dir.chdir("/Users/luke/Desktop/pics") do
            graph.induced_subgraph(gv).write_to_graphic_file('jpg', 'graph')
        end
    end
end

# $Id$