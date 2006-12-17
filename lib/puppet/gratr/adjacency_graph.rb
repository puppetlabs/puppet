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


require 'puppet/gratr/edge'
require 'puppet/gratr/graph'
require 'set'

module GRATR

  # This provides the basic routines needed to implement the Digraph, UndirectedGraph,
  # PseudoGraph, DirectedPseudoGraph, MultiGraph and DirectedPseudoGraph class.
  module AdjacencyGraph
    
    include Graph

    class ArrayWithAdd < Array # :nodoc:
      alias add push
    end

    # Initialization parameters can include an Array of edges to add, Graphs to
    # copy (will merge if multiple)
    # :parallel_edges denotes that duplicate edges are allowed
    # :loops denotes that loops are allowed
    def initialize(*params)
      @vertex_dict     = Hash.new    
      raise ArgumentError if params.any? do |p| 
        !(p.kind_of? GRATR::Graph or 
          p.kind_of? Array or 
          p == :parallel_edges or
          p == :loops)
      end
      clear_all_labels

      # Basic configuration of adjacency
      @allow_loops    = params.any? {|p| p == :loops}
      @parallel_edges = params.any? {|p| p == :parallel_edges}
      @edgelist_class = @parallel_edges ? ArrayWithAdd : Set
      if @parallel_edges
        @edge_number      = Hash.new
        @next_edge_number = 0 
      end

      # Copy any given graph into this graph
      params.select {|p| p.kind_of? GRATR::Graph}.each do |g|
        g.edges.each do |e| 
          add_edge!(e)
          edge_label_set(e, edge_label(e)) if edge_label(e)
        end
        g.vertices.each do |v|
          vertex_label_set(v, vertex_label(v)) if vertex_label(v)
        end  
      end

      # Add all array edges specified
      params.select {|p| p.kind_of? Array}.each do |a|
        0.step(a.size-1, 2) {|i| add_edge!(a[i], a[i+1])}
      end

    end

    # Returns true if v is a vertex of this Graph
    # An O(1) implementation of vertex?
    def vertex?(v) @vertex_dict.has_key?(v); end

    # Returns true if [u,v] or u is an Edge
    # An O(1) implementation 
    def edge?(u, v=nil)
      u, v = u.source, u.target if u.kind_of? GRATR::Edge
      vertex?(u) and @vertex_dict[u].include?(v)
    end

    # Adds a vertex to the graph with an optional label
    def add_vertex!(vertex, label=nil)
      @vertex_dict[vertex] ||= @edgelist_class.new
      self[vertex] = label if label
      self
    end

    # Adds an edge to the graph
    # Can be called in two basic ways, label is optional
    #   * add_edge!(Edge[source,target], "Label")
    #   * add_edge!(source,target, "Label")
    def add_edge!(u, v=nil, l=nil, n=nil)
      if u.class.include? EdgeNumber and n.nil?
          n = u.number
      end
      if u.kind_of? GRATR::Edge
          edge = u
          u, v, l = u.source, u.target, u.label
      end
      if not @allow_loops and u == v
          return self
      end
      if @parallel_edges and ! n
          n = (@next_edge_number+=1)
      end
      add_vertex!(u);
      add_vertex!(v)        
      @vertex_dict[u].add(v)

      if @parallel_edges
          (@edge_number[u] ||= @edgelist_class.new).add(n)
      end
      unless directed?
        @vertex_dict[v].add(u)
        if @parallel_edges
            (@edge_number[v] ||= @edgelist_class.new).add(n)
        end
      end        

      if l
          unless edge
              if n
                  edge = edge_class[u,v,n]
              else
                  edge = edge_class[u,v]
              end
          end
          self[edge] = l
      end
      self
    end

    # Removes a given vertex from the graph
    def remove_vertex!(v)
# FIXME This is broken for multi graphs 
      @vertex_dict.delete(v)
      @vertex_dict.each_value { |adjList| adjList.delete(v) }
      @vertex_dict.keys.each  do |u| 
        delete_label(edge_class[u,v]) 
        delete_label(edge_class[v,u])
      end
      delete_label(v) 
      self
    end

    # Removes an edge from the graph, can be called with source and target or with
    # and object of GRATR::Edge derivation
    def remove_edge!(u, v=nil)
      unless u.kind_of? GRATR::Edge
        raise ArgumentError if @parallel_edges
        u = edge_class[u,v]
      end
      raise ArgumentError if @parallel_edges and (u.number || 0) == 0
      return self unless @vertex_dict[u.source] # It doesn't exist
      delete_label(u) # Get rid of label
      if @parallel_edges
        index = @edge_number[u.source].index(u.number)
        raise NoEdgeError unless index
        @vertex_dict[u.source].delete_at(index)
        @edge_number[u.source].delete_at(index) 
      else
        @vertex_dict[u.source].delete(u.target) 
      end
      self
    end

    # Returns an array of vertices that the graph has
    def vertices() @vertex_dict.keys; end

    # Returns an array of edges, most likely of class Edge or UndirectedEdge depending 
    # upon the type of graph
    def edges
      @vertex_dict.keys.inject(Set.new) do |a,v|
        if @parallel_edges and @edge_number[v]
          @vertex_dict[v].zip(@edge_number[v]).each do |w|
            s,t,n = v,w[0],w[1]
            a.add( edge_class[ s,t,n, edge_label(s,t,n) ] )
          end
        else
          @vertex_dict[v].each do |w|
            a.add(edge_class[v,w,edge_label(v,w)])
          end
        end; a
      end.to_a
    end
 
    alias graph_adjacent adjacent
    def adjacent(x, options={})
        unless @vertex_dict.has_key?(x)
            raise ArgumentError, "%s is not a vertex" % x
        end
      options[:direction] ||= :out
      if !x.kind_of?(GRATR::Edge) and (options[:direction] == :out || !directed?)
        if options[:type] == :edges
          @parallel_edges ?
            @vertex_dict[x].map {|v| e=edge_class[x,v,@edge_number[x][v]]; e.label = self[e]; e} :
            @vertex_dict[x].map {|v| e=edge_class[x,v];  e.label = self[e]; e}
        else
          @vertex_dict[x].to_a
        end
      else
        graph_adjacent(x,options)
      end
    end
    
 
  public

    def self.included(cl)
      # Shortcut for creating a Graph
      #
      #  Example: GRATR::Digraph[1,2, 2,3, 2,4, 4,5].edges.to_a.to_s =>
      #    "(1-2)(2-3)(2-4)(4-5)"
      # 
      # Or as a Hash for specifying lables
      # GRATR::Digraph[ [:a,:b] => 3, [:b,:c] => 4 ]  (Note: Do not use for Multi or Pseudo graphs)
      def cl.[] (*a)
        result = new
        if a.size == 1 and a[0].kind_of? Hash
          # Convert to edge class
          a[0].each do |k,v|
            if result.edge_class.include? GRATR::EdgeNumber
              result.add_edge!(result.edge_class[k[0],k[1],nil,v])
            else
             result.add_edge!(result.edge_class[k[0],k[1],v])
            end 
          end
        elsif a[0].kind_of? GRATR::Edge
          a.each{|e| result.add_edge!(e); result[e] = e.label}
        elsif a.size % 2 == 0    
          0.step(a.size-1, 2) {|i| result.add_edge!(a[i], a[i+1])}
        else
          raise ArgumentError
        end
        result
      end
    end
          
  end # Adjacency Graph
end # GRATR
