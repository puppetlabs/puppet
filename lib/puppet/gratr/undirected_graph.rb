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


require 'puppet/gratr/adjacency_graph'
require 'puppet/gratr/search'
require 'puppet/gratr/biconnected'
require 'puppet/gratr/comparability'
require 'set'

module GRATR
  class UndirectedGraph
    include AdjacencyGraph
    include Graph::Search
    include Graph::Biconnected
    include Graph::Comparability
    
    def initialize(*params)
      raise ArgumentError if params.any? do |p| 
       !(p.kind_of? GRATR::Graph or p.kind_of? Array)
      end if self.class == GRATR::UndirectedGraph
      super(*params)
    end 

    # UndirectedGraph is by definition undirected, always returns false
    def directed?()  false; end
      
    # Redefine degree (default was sum)
    def degree(v)    in_degree(v); end
      
    # A vertex of an undirected graph is balanced by definition
    def balanced?(v)  true;  end

    # UndirectedGraph uses UndirectedEdge for the edge class.
    def edge_class() @parallel_edges ? GRATR::MultiUndirectedEdge : GRATR::UndirectedEdge; end

    def remove_edge!(u, v=nil)
      unless u.kind_of? GRATR::Edge
        raise ArgumentError if @parallel_edges 
        u = edge_class[u,v]
      end
      super(u.reverse) unless u.source == u.target
      super(u)
    end
    
    # A triangulated graph is an undirected perfect graph that every cycle of length greater than
    # three possesses a chord. They have also been called chordal, rigid circuit, monotone transitive,
    # and perfect elimination graphs.
    #
    # Implementation taken from Golumbic's, "Algorithmic Graph Theory and
    # Perfect Graphs" pg. 90
    def triangulated?
      a = Hash.new {|h,k| h[k]=Set.new}; sigma=lexicograph_bfs
      inv_sigma = sigma.inject({}) {|acc,val| acc[val] = sigma.index(val); acc}
      sigma[0..-2].each do |v|
        x = adjacent(v).select {|w| inv_sigma[v] < inv_sigma[w] }
        unless x.empty?
           u = sigma[x.map {|y| inv_sigma[y]}.min]
           a[u].merge(x - [u])
        end
        return false unless a[v].all? {|z| adjacent?(v,z)}
      end
      true
    end
    
    def chromatic_number
      return triangulated_chromatic_number if triangulated?
      raise NotImplementedError    
    end
    
    # An interval graph can have its vertices into one-to-one
    # correspondence with a set of intervals F of a linearly ordered
    # set (like the real line) such that two vertices are connected
    # by an edge of G if and only if their corresponding intervals
    # have nonempty intersection.
    def interval?() triangulated? and complement.comparability?; end
    
    # A permutation diagram consists of n points on each of two parallel
    # lines and n straight line segments matchin the points. The intersection
    # graph of the line segments is called a permutation graph.
    def permutation?() comparability? and complement.comparability?; end
    
    # An undirected graph is defined to be split if there is a partition
    # V = S + K of its vertex set into a stable set S and a complete set K.    
    def split?() triangulated? and complement.triangulated?; end
    
   private
   # Implementation taken from Golumbic's, "Algorithmic Graph Theory and
   # Perfect Graphs" pg. 99
    def triangulated_chromatic_number
      chi = 1; s= Hash.new {|h,k| h[k]=0}
      sigma=lexicograph_bfs
      inv_sigma = sigma.inject({}) {|acc,val| acc[val] = sigma.index(val); acc}
      sigma.each do |v|
        x = adjacent(v).select {|w| inv_sigma[v] < inv_sigma[w] }
        unless x.empty?
          u = sigma[x.map {|y| inv_sigma[y]}.min]
          s[u] = [s[u], x.size-1].max
          chi = [chi, x.size+1].max if s[v] < x.size
        end
      end; chi
    end
   
  end # UndirectedGraph

  # This is a UndirectedGraph that allows for parallel edges, but does not
  # allow loops
  class UndirectedPseudoGraph < UndirectedGraph
    def initialize(*params)
      raise ArgumentError if params.any? do |p| 
       !(p.kind_of? Graph or p.kind_of? Array)
      end
      super(:parallel_edges, *params)
    end 
  end

  # This is a UndirectedGraph that allows for parallel edges and loops
  class UndirectedMultiGraph < UndirectedGraph
    def initialize(*params)
      raise ArgumentError if params.any? do |p| 
       !(p.kind_of? Graph or p.kind_of? Array)
      end
      super(:parallel_edges, :loops, *params)
    end 
  end


end # GRATR
