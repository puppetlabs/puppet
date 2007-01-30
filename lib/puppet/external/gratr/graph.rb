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
require 'puppet/external/gratr/labels'
require 'puppet/external/gratr/graph_api'

module GRATR
  
  # Using the functions required by the GraphAPI, it implements all the
  # basic functions of a Graph class by using only functions in GraphAPI.
  # An actual implementation still needs to be done, as in Digraph or
  # UndirectedGraph.
  module Graph
    include Enumerable
    include Labels
    include GraphAPI
      
    # Non destructive version of add_vertex!, returns modified copy of Graph
    def add_vertex(v, l=nil) x=self.class.new(self); x.add_vertex!(v,l); end
      
    # Non destructive version add_edge!, returns modified copy of Graph  
    def add_edge(u, v=nil, l=nil) x=self.class.new(self); x.add_edge!(u,v,l); end
      
    # Non destructive version of remove_vertex!, returns modified copy of Graph
    def remove_vertex(v) x=self.class.new(self); x.remove_vertex!(v); end  

    # Non destructive version of remove_edge!, returns modified copy of Graph
    def remove_edge(u,v=nil) x=self.class.new(self); x.remove_edge!(u,v); end
      
    # Return Array of adjacent portions of the Graph
    #  x can either be a vertex an edge.
    #  options specifies parameters about the adjacency search
    #   :type can be either :edges or :vertices (default).
    #   :direction can be :in, :out(default) or :all.
    #
    # Note: It is probably more efficently done in implementation.
    def adjacent(x, options={})
      d = directed? ? (options[:direction] || :out) : :all

      # Discharge the easy ones first
      return [x.source] if x.kind_of? Edge and options[:type] == :vertices and d == :in
      return [x.target] if x.kind_of? Edge and options[:type] == :vertices and d == :out
      return [x.source, x.target] if x.kind_of? Edge and options[:type] != :edges and d == :all

      (options[:type] == :edges ? edges : to_a).select {|u| adjacent?(x,u,d)}
    end

    # Add all objects in _a_ to the vertex set.
    def add_vertices!(*a) a.each {|v| add_vertex! v}; self; end
      
    # See add_vertices!

    def add_vertices(*a) x=self.class.new(self); x.add_vertices(*a); self; end

    # Add all edges in the _edges_ Enumerable to the edge set.  Elements of the
    # Enumerable can be both two-element arrays or instances of DirectedEdge or
    # UnDirectedEdge. 
    def add_edges!(*args) args.each { |edge| add_edge!(edge) }; self; end
      
    # See add_edge!
    def add_edges(*a) x=self.class.new(self); x.add_edges!(*a); self; end

    # Remove all vertices specified by the Enumerable a from the graph by
    # calling remove_vertex!.
    def remove_vertices!(*a) a.each { |v| remove_vertex! v }; end
      
    # See remove_vertices!
    def remove_vertices(*a) x=self.class.new(self); x.remove_vertices(*a); end

    # Remove all vertices edges by the Enumerable a from the graph by
    # calling remove_edge!
    def remove_edges!(*a) a.each { |e| remove_edges! e }; end

    # See remove_edges
    def remove_edges(*a) x=self.class.new(self); x.remove_edges(*a); end

    # Execute given block for each vertex, provides for methods in Enumerable
    def each(&block) vertices.each(&block); end

    # Returns true if _v_ is a vertex of the graph.
    # This is a default implementation that is of O(n) average complexity.
    # If a subclass uses a hash to store vertices, then this can be
    # made into an O(1) average complexity operation.
    def vertex?(v) vertices.include?(v); end  
    
    # Returns true if u or (u,v) is an Edge of the graph.
    def edge?(*arg) edges.include?(edge_convert(*args)); end  

    # Tests two objects to see if they are adjacent.
    # direction parameter specifies direction of adjacency, :in, :out, or :all(default)
    # All denotes that if there is any adjacency, then it will return true.
    # Note that the default is different than adjacent where one is primarily concerned with finding
    # all adjacent objects in a graph to a given object. Here the concern is primarily on seeing
    # if two objects touch. For vertexes, any edge between the two will usually do, but the direction
    # can be specified if need be.
    def adjacent?(source, target, direction=:all)
      if source.kind_of? GRATR::Edge
        raise NoEdgeError unless edge? source
        if target.kind_of? GRATR::Edge
          raise NoEdgeError unless edge? target
          (direction != :out and source.source == target.target) or (direction != :in and source.target == target.source)
        else
          raise NoVertexError unless vertex? target
          (direction != :out and source.source == target)  or (direction != :in and source.target == target)
        end
      else
        raise NoVertexError unless vertex? source
        if target.kind_of? GRATR::Edge
          raise NoEdgeError unless edge? target
          (direction != :out and source == target.target) or (direction != :in and source == target.source)
        else
          raise NoVertexError unless vertex? target
          (direction != :out and edge?(target,source)) or (direction != :in and edge?(source,target))
        end
      end
    end

    # Returns true if the graph has no vertex, i.e. num_vertices == 0.
    def empty?() vertices.size.zero?; end

    # Returns true if the given object is a vertex or Edge in the Graph.
    # 
    def include?(x) x.kind_of?(GRATR::Edge) ? edge?(x) : vertex?(x); end

    # Returns the neighboorhood of the given vertex (or Edge)
    # This is equivalent to adjacent, but bases type on the type of object.
    # direction can be :all, :in, or :out 
    def neighborhood(x, direction = :all)
      adjacent(x, :direction => direction, :type => ((x.kind_of? GRATR::Edge) ? :edges : :vertices )) 
    end
    
    # Union of all neighborhoods of vertices (or edges) in the Enumerable x minus the contents of x
    # Definition taken from Jorgen Bang-Jensen, Gregory Gutin, _Digraphs: Theory, Algorithms and Applications_, pg 4
    def set_neighborhood(x, direction = :all)
      x.inject(Set.new) {|a,v| a.merge(neighborhood(v,direction))}.reject {|v2| x.include?(v2)}
    end  
    
    # Union of all set_neighborhoods reachable in p edges
    # Definition taken from Jorgen Bang-Jensen, Gregory Gutin, _Digraphs: Theory, Algorithms and Applications_, pg 46
    def closed_pth_neighborhood(w,p,direction=:all)
      if p <= 0
        w 
      elsif p == 1
        (w + set_neighborhood(w,direction)).uniq
      else
        n = set_neighborhood(w, direction)
        (w + n + closed_pth_neighborhood(n,p-1,direction)).uniq
      end
    end
    
    # Returns the neighboorhoods reachable in p steps from every vertex (or edge)
    # in the Enumerable x        
    # Definition taken from Jorgen Bang-Jensen, Gregory Gutin, _Digraphs: Theory, Algorithms and Applications_, pg 46
    def open_pth_neighborhood(x, p, direction=:all)
      if    p <= 0
        x
      elsif p == 1
        set_neighborhood(x,direction)
      else  
        set_neighborhood(open_pth_neighborhood(x, p-1, direction),direction) - closed_pth_neighborhood(x,p-1,direction)
      end    
    end
    
    # Returns the number of out-edges (for directed graphs) or the number of
    # incident edges (for undirected graphs) of vertex _v_.
    def out_degree(v) adjacent(v, :direction => :out).size; end

    # Returns the number of in-edges (for directed graphs) or the number of
    # incident edges (for undirected graphs) of vertex _v_.
    def in_degree(v)  adjacent(v, :direction => :in ).size; end

    # Returns the sum of the number in and out edges for a vertex
    def degree(v) in_degree(v) + out_degree(v); end

    # Minimum in-degree 
    def min_in_degree() to_a.map {|v| in_degree(v)}.min; end

    # Minimum out-degree
    def min_out_degree() to_a.map {|v| out_degree(v)}.min; end

    # Minimum degree of all vertexes
    def min_degree() [min_in_degree, min_out_degree].min; end

    # Maximum in-degree 
    def max_in_degree() vertices.map {|v| in_degree(v)}.max; end

    # Maximum out-degree
    def max_out_degree() vertices.map {|v| out_degree(v)}.max; end

    # Minimum degree of all vertexes
    def max_degree() [max_in_degree, max_out_degree].max; end

    # Regular
    def regular?() min_degree == max_degree; end

    # Returns the number of vertices.
    def size()         vertices.size; end

    # Synonym for size.
    def num_vertices() vertices.size; end

    # Returns the number of edges.
    def num_edges()    edges.size; end

    # Utility method to show a string representation of the edges of the graph.
    def to_s() edges.to_s; end

    # Equality is defined to be same set of edges and directed?
    def eql?(g) 
      return false unless g.kind_of? GRATR::Graph

      (g.directed?   == self.directed?)  and 
      (vertices.sort == g.vertices.sort) and
      (g.edges.sort  == edges.sort)
    end

    # Synonym for eql?
    def ==(rhs) eql?(rhs); end

    # Merge another graph into this one
    def merge(other)
      other.vertices.each {|v| add_vertex!(v)      }
      other.edges.each    {|e| add_edge!(e)         }
      other.edges.each    {|e| add_edge!(e.reverse) } if directed? and !other.directed? 
      self 
    end

    # A synonym for merge, that doesn't modify the current graph
    def +(other)
      result = self.class.new(self)
      case other
        when GRATR::Graph : result.merge(other)
        when GRATR::Edge  : result.add_edge!(other)
        else              result.add_vertex!(other)
      end
    end

    # Remove all vertices in the specified right hand side graph
    def -(other)
      case  other
        when GRATR::Graph : induced_subgraph(vertices - other.vertices)
        when GRATR::Edge  : self.class.new(self).remove_edge!(other)
        else              self.class.new(self).remove_vertex!(other)
      end
    end

    # A synonym for add_edge!
    def <<(edge) add_edge!(edge); end

    # Return the complement of the current graph
    def complement
      vertices.inject(self.class.new) do |a,v|
        a.add_vertex!(v)
        vertices.each {|v2| a.add_edge!(v,v2) unless edge?(v,v2) }; a
      end
    end

    # Given an array of vertices return the induced subgraph
    def induced_subgraph(v)
      edges.inject(self.class.new) do |a,e| 
        ( v.include?(e.source) and v.include?(e.target) ) ?  (a << e) : a
      end;
    end
    
    def inspect
      l = vertices.select {|v| self[v]}.map {|u| "vertex_label_set(#{u.inspect},#{self[u].inspect})"}.join('.')
      self.class.to_s + '[' + edges.map {|e| e.inspect}.join(', ') + ']' + (l ? '.'+l : '')
    end
    
   private
    def edge_convert(*args) args[0].kind_of?(GRATR::Edge) ? args[0] : edge_class[*args]; end
    

  end # Graph

end # GRATR
