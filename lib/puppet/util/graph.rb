#  Created by Luke Kanies on 2006-11-16.
#  Copyright (c) 2006. All rights reserved.

require 'puppet'
require 'puppet/simple_graph'

# A module that handles the small amount of graph stuff in Puppet.
module Puppet::Util::Graph
    # Make a graph where each of our children gets converted to
    # the receiving end of an edge.  Call the same thing on all
    # of our children, optionally using a block
    def to_graph(graph = nil, &block)
        # Allow our calling function to send in a graph, so that we
        # can call this recursively with one graph.
        graph ||= Puppet::SimpleGraph.new

        self.each do |child|
            unless block_given? and ! yield(child)
                graph.add_edge(self, child)

                if child.respond_to?(:to_graph)
                    child.to_graph(graph, &block)
                end
            end
        end

        # Do a topsort, which will throw an exception if the graph is cyclic.

        graph
    end
end

