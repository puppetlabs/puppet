#--
# Copyright (c) 2006 Shawn Patrick Garbett
# Copyright (c) 2002,2004,2005 by Horst Duchene
# 
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
# 
#     * Redistributions of source code must retain the above copyright notice(s),
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the documentation
#       and/or other materials provided with the distribution.
#     * Neither the name of the Shawn Garbett nor the names of its contributors
#       may be used to endorse or promote products derived from this software
#       without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#++

require 'puppet/external/gratr/edge'
require 'puppet/external/gratr/graph'
require 'puppet/external/gratr/search'
require 'puppet/external/gratr/adjacency_graph'
require 'puppet/external/gratr/strong_components'
require 'puppet/external/gratr/digraph_distance'
require 'puppet/external/gratr/chinese_postman'

module GRATR
  #
  # Digraph is a directed graph which is a finite set of vertices
  # and a finite set of edges connecting vertices. It cannot contain parallel
  # edges going from the same source vertex to the same target. It also
  # cannot contain loops, i.e. edges that go have the same vertex for source 
  # and target.
  #
  # DirectedPseudoGraph is a class that allows for parallel edges, and a
  # DirectedMultiGraph is a class that allows for parallel edges and loops
  # as well.
  class Digraph
    include AdjacencyGraph
    include Graph::Search
    include Graph::StrongComponents
    include Graph::Distance
    include Graph::ChinesePostman
  
    def initialize(*params)
      raise ArgumentError if params.any? do |p| 
       !(p.kind_of? GRATR::Graph or p.kind_of? Array)
      end if self.class == GRATR::Digraph
      super(*params)
    end 

    # A directed graph is directed by definition
    def directed?() true; end

    # A digraph uses the Edge class for edges
    def edge_class() @parallel_edges ? GRATR::MultiEdge : GRATR::Edge; end

    # Reverse all edges in a graph
    def reversal
      return new(self) unless directed?
      result = self.class.new
      edges.inject(result) {|a,e| a << e.reverse}
      vertices.each { |v| result.add_vertex!(v) unless result.vertex?(v) }
      result
    end

    # Return true if the Graph is oriented.
    def oriented?
      e = edges
      re = e.map {|x| x.reverse}
      not e.any? {|x| re.include?(x)}
    end
    
    # Balanced is when the out edge count is equal to the in edge count
    def balanced?(v) out_degree(v) == in_degree(v); end
    
    # Returns out_degree(v) - in_degree(v)
    def delta(v) out_degree(v) - in_degree(v); end
          
  end

  # DirectedGraph is just an alias for Digraph should one desire
  DirectedGraph = Digraph

  # This is a Digraph that allows for parallel edges, but does not
  # allow loops
  class DirectedPseudoGraph < Digraph
    def initialize(*params)
      raise ArgumentError if params.any? do |p| 
       !(p.kind_of? GRATR::Graph or p.kind_of? Array)
      end
      super(:parallel_edges, *params)
    end 
  end

  # This is a Digraph that allows for parallel edges and loops
  class DirectedMultiGraph < Digraph
    def initialize(*params)
      raise ArgumentError if params.any? do |p| 
       !(p.kind_of? GRATR::Graph or p.kind_of? Array)
      end
      super(:parallel_edges, :loops, *params)
    end 
  end

end
