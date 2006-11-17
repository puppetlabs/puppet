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


module GRATR
  module Graph
    module Search

      # Options are mostly callbacks passed in as a hash. 
      # The following are valid, anything else is ignored
      # :enter_vertex  => Proc  Called upon entry of a vertex
      # :exit_vertex   => Proc  Called upon exit of a vertex
      # :root_vertex   => Proc  Called when a vertex the a root of a tree
      # :start_vertex  => Proc  Called for the first vertex of the search
      # :examine_edge  => Proc  Called when an edge is examined
      # :tree_edge     => Proc  Called when the edge is a member of the tree
      # :back_edge     => Proc  Called when the edge is a back edge
      # :forward_edge  => Proc  Called when the edge is a forward edge
      # :adjacent      => Proc that given a vertex returns adjacent nodes, defaults to adjacent call of graph useful for changing the definition of adjacent in some algorithms
      #
      # :start         => Vertex  Specifies the vertex to start search from
      #
      # If a &block is specified it defaults to :enter_vertex
      #
      # Returns the list of vertexes as reached by enter_vertex
      # This allows for calls like, g.bfs.each {|v| ...}
      #
      # Can also be called like bfs_examine_edge {|e| ... } or
      # dfs_back_edge {|e| ... } for any of the callbacks
      #
      # A full example usage is as follows:
      #
      #  ev = Proc.new {|x| puts "Enter Vertex #{x}"}
      #  xv = Proc.new {|x| puts "Exit Vertex #{x}"}
      #  sv = Proc.new {|x| puts "Start Vertex #{x}"}
      #  ee = Proc.new {|x| puts "Examine Edge #{x}"}
      #  te = Proc.new {|x| puts "Tree Edge #{x}"}
      #  be = Proc.new {|x| puts "Back Edge #{x}"}
      #  fe = Proc.new {|x| puts "Forward Edge #{x}"}
      #  Digraph[1,2,2,3,3,4].dfs({ 
      #        :enter_vertex => ev, 
      #        :exit_vertex  => xv,
      #        :start_vertex => sv,
      #        :examine_edge => ee,
      #        :tree_edge    => te,
      #        :back_edge    => be,
      #        :forward_edge => fe })
      # 
      # Which outputs:
      #
      # Start Vertex 1
      # Enter Vertex 1
      # Examine Edge (1=2)
      # Tree Edge (1=2)
      # Enter Vertex 2
      # Examine Edge (2=3)
      # Tree Edge (2=3)
      # Enter Vertex 3
      # Examine Edge (3=4)
      # Tree Edge (3=4)
      # Enter Vertex 4
      # Examine Edge (1=4)
      # Back Edge (1=4)
      # Exit Vertex 4
      # Exit Vertex 3
      # Exit Vertex 2
      # Exit Vertex 1
      def bfs(options={}, &block) gratr_search_helper(:shift, options, &block); end

      # See options for bfs method
      def dfs(options={}, &block) gratr_search_helper(:pop,   options, &block); end
      
      # Routine to compute a spanning forest for the given search method
      # Returns two values, first is a hash of predecessors and second an array of root nodes
      def spanning_forest(start, routine)
        predecessor = {}
        roots       = []
        te = Proc.new {|e| predecessor[e.target] = e.source}
        rv = Proc.new {|v| roots << v}
        method(routine).call :start => start, :tree_edge => te, :root_vertex => rv
        [predecessor, roots]
      end
      
      # Return the dfs spanning forest for the given start node, see spanning_forest
      def dfs_spanning_forest(start) spanning_forest(start, :dfs); end
      
      # Return the bfs spanning forest for the given start node, see spanning_forest
      def bfs_spanning_forest(start) spanning_forest(start, :bfs); end
      
      # Returns a hash of predecessors in a tree rooted at the start node. If this is a connected graph
      # then it will be a spanning tree and contain all vertices. An easier way to tell if it's a spanning tree is to
      # use a spanning_forest call and check if there is a single root node.
      def tree_from_vertex(start, routine)
        predecessor={}
        correct_tree = false
        te = Proc.new {|e| predecessor[e.target] = e.source if correct_tree}
        rv = Proc.new {|v| correct_tree = (v == start)}
        method(routine).call :start => start, :tree_edge => te, :root_vertex => rv
        predecessor       
      end
      
      # Returns a hash of predecessors for the depth first search tree rooted at the given node
      def dfs_tree_from_vertex(start) tree_from_vertex(start, :dfs); end
      
      # Returns a hash of predecessors for the depth first search tree rooted at the given node
      def bfs_tree_from_vertex(start) tree_from_vertex(start, :bfs); end
       
      # An inner class used for greater efficiency in lexicograph_bfs
      #
      # Original desgn taken from Golumbic's, "Algorithmic Graph Theory and
      # Perfect Graphs" pg, 87-89
      class LexicographicQueue
      
        # Called with the initial values (array)
        def initialize(values)
          @node = Struct.new(:back, :forward, :data)
          @node.class_eval { def hash() @hash; end; @@cnt=0 }
          @set  = {}
          @tail = @node.new(nil, nil, Array.new(values))
          @tail.instance_eval { @hash = (@@cnt+=1) }
          values.each {|a| @set[a] = @tail}        
        end
     
        # Pop an entry with maximum lexical value from queue 
        def pop()
          return nil unless @tail
          value = @tail[:data].pop
          @tail = @tail[:forward] while @tail and @tail[:data].size == 0
          @set.delete(value); value
        end
      
        # Increase lexical value of given values (array)
        def add_lexeme(values)
          fix = {}
          values.select {|v| @set[v]}.each do |w|
            sw = @set[w]
            if fix[sw]
              s_prime        = sw[:back]
            else 
              s_prime             = @node.new(sw[:back], sw, [])
              s_prime.instance_eval { @hash = (@@cnt+=1) }
              @tail = s_prime if @tail == sw
              sw[:back][:forward] = s_prime if sw[:back]
              sw[:back]           = s_prime
              fix[sw]             = true
            end
            s_prime[:data] << w
            sw[:data].delete(w)
            @set[w] = s_prime
          end
          fix.keys.select {|n| n[:data].size == 0}.each do |e|
            e[:forward][:back] = e[:back] if e[:forward]
            e[:back][:forward] = e[:forward] if e[:back]
          end
        end 
      
      end
    
      # Lexicographic breadth-first search, the usual queue of vertices
      # is replaced by a queue of unordered subsets of the vertices,
      # which is sometimes refined but never reordered.
      # 
      # Originally developed by Rose, Tarjan, and Leuker, "Algorithmic
      # aspects of vertex elimination on graphs", SIAM J. Comput. 5, 266-283
      # MR53 #12077
      #
      # Implementation taken from Golumbic's, "Algorithmic Graph Theory and
      # Perfect Graphs" pg, 84-90
      def lexicograph_bfs(&block)
        lex_q = GRATR::Graph::Search::LexicographicQueue.new(vertices)
        result = []
        num_vertices.times do               
          v = lex_q.pop
          result.unshift(v)
          lex_q.add_lexeme(adjacent(v))            
        end
        result.each {|r| block.call(r)} if block
        result
      end


      # A* Heuristic best first search
      # 
      # start is the starting vertex for the search
      #
      # func is a Proc that when passed a vertex returns the heuristic 
      #   weight of sending the path through that node. It must always
      #   be equal to or less than the true cost
      # 
      # options are mostly callbacks passed in as a hash, the default block is 
      # :discover_vertex and weight is assumed to be the label for the Edge.
      # The following options are valid, anything else is ignored.
      #
      # * :weight => can be a Proc, or anything else is accessed using the [] for the
      #     the label or it defaults to using
      #     the value stored in the label for the Edge. If it is a Proc it will 
      #     pass the edge to the proc and use the resulting value.
      # * :discover_vertex => Proc invoked when a vertex is first discovered
      #   and is added to the open list.
      # * :examine_vertex  => Proc invoked when a vertex is popped from the
      #   queue (i.e., it has the lowest cost on the open list).
      # * :examine_edge    => Proc invoked on each out-edge of a vertex
      #   immediately after it is examined.
      # * :edge_relaxed    => Proc invoked on edge (u,v) if d[u] + w(u,v) < d[v].
      # * :edge_not_relaxed=> Proc invoked if the edge is not relaxed (see above).
      # * :black_target    => Proc invoked when a vertex that is on the closed 
      #     list is "rediscovered" via a more efficient path, and is re-added
      #     to the OPEN list.
      # * :finish_vertex    => Proc invoked on a vertex when it is added to the 
      #     closed list, which happens after all of its out edges have been
      #     examined. 
      #
      # Returns array of nodes in path, or calls block on all nodes, 
      # upon failure returns nil
      #
      # Can also be called like astar_examine_edge {|e| ... } or
      # astar_edge_relaxed {|e| ... } for any of the callbacks
      #
      # The criteria for expanding a vertex on the open list is that it has the
      # lowest f(v) = g(v) + h(v) value of all vertices on open.
      #
      # The time complexity of A* depends on the heuristic. It is exponential 
      # in the worst case, but is polynomial when the heuristic function h
      # meets the following condition: |h(x) - h*(x)| < O(log h*(x)) where h*  
      # is the optimal heuristic, i.e. the exact cost to get from x to the goal.
      #
      # Also see: http://en.wikipedia.org/wiki/A-star_search_algorithm
      #
      def astar(start, goal, func, options, &block)
        options.instance_eval "def handle_vertex(sym,u) self[sym].call(u) if self[sym]; end"
        options.instance_eval "def handle_edge(sym,u,v) self[sym].call(#{edge_class}[u,v]) if self[sym]; end"

        d = { start => 0 }
        f = { start => func.call(start) }
        color = {start => :gray}
        p = Hash.new {|k| p[k] = k}
        queue = [start]
        block.call(start) if block
        until queue.empty?
          u = queue.pop
          options.handle_vertex(:examine_vertex, u)
          adjacent(u).each do |v|
            e = edge_class[u,v]
            options.handle_edge(:examine_edge, u, v)
            w = cost(e, options[:weight])
            raise ArgumentError unless w
            if d[v].nil? or (w + d[u]) < d[v] 
              options.handle_edge(:edge_relaxed, u, v)
              d[v] = w + d[u]
              f[v] = d[v] + func.call(u)
              p[v] = u
              unless color[v] == :gray
                options.handle_vertex(:black_target, v) if color[v] == :black
                color[v] = :gray 
                options.handle_vertex(:discover_vertex, v)
                queue << v 
                block.call(v) if block
                return [start]+queue if v == goal
              end
            else
              options.handle_edge(:edge_not_relaxed, u, v)
            end
          end # adjacent(u)
          color[u] = :black
          options.handle_vertex(:finish_vertex,u)
        end # queue.empty?
        nil # failure, on fall through
      end # astar
    
      # Best first has all the same options as astar with func set to h(v) = 0.
      # There is an additional option zero which should be defined to zero
      # for the operation '+' on the objects used in the computation of cost.
      # The parameter zero defaults to 0.
      def best_first(start, goal, options, zero=0, &block)
        func = Proc.new {|v| zero}   
        astar(start, goal, func, options, &block)
      end

      alias_method :pre_search_method_missing, :method_missing # :nodoc: 
      def method_missing(sym,*args, &block) # :nodoc:
        m1=/^dfs_(\w+)$/.match(sym.to_s)
        dfs((args[0] || {}).merge({m1.captures[0].to_sym => block})) if m1
        m2=/^bfs_(\w+)$/.match(sym.to_s)
        bfs((args[0] || {}).merge({m2.captures[0].to_sym => block})) if m2
        pre_search_method_missing(sym, *args, &block) unless m1 or m2
      end

     private

      def gratr_search_helper(op, options={}, &block) # :nodoc: 
        return nil if size == 0
        result = []
        # Create options hash that handles callbacks
        options = {:enter_vertex => block, :start => to_a[0]}.merge(options)
        options.instance_eval "def handle_vertex(sym,u) self[sym].call(u) if self[sym]; end"
        options.instance_eval "def handle_edge(sym,e) self[sym].call(e) if self[sym]; end"
        # Create waiting list that is a queue or stack depending on op specified.
        # First entry is the start vertex.
        waiting = [options[:start]]
        waiting.instance_eval "def next() #{op.to_s}; end" 
        # Create color map with all set to unvisited except for start vertex
        # will be set to waiting
        color_map = vertices.inject({}) {|a,v| a[v] = :unvisited; a}
        color_map.merge!(waiting[0] => :waiting)
        options.handle_vertex(:start_vertex, waiting[0])
        options.handle_vertex(:root_vertex,  waiting[0])
        # Perform the actual search until nothing is waiting
        until waiting.empty?
          # Loop till the search iterator exhausts the waiting list
          visited_edges={} # This prevents retraversing edges in undirected graphs
          until waiting.empty?
            gratr_search_iteration(options, waiting, color_map, visited_edges, result, op == :pop) 
          end
          # Waiting list is exhausted, see if a new root vertex is available
          u=color_map.detect {|key,value| value == :unvisited}
          waiting.push(u[0]) if u
          options.handle_vertex(:root_vertex, u[0]) if u
        end; result
      end

      def gratr_search_iteration(options, waiting, color_map, visited_edges, result, recursive=false) # :nodoc:
        # Get the next waiting vertex in the list
        u = waiting.next  
        options.handle_vertex(:enter_vertex,u)
        result << u
        # Examine all adjacent outgoing edges, not previously traversed
        adj_proc = options[:adjacent] || self.method(:adjacent).to_proc
        adj_proc.call(u,:type => :edges, :direction => :out).reject {|w| visited_edges[w]}.each do |e|
          e = e.reverse unless directed? or e.source == u # Preserves directionality where required 
          v = e.target
          options.handle_edge(:examine_edge, e)
          visited_edges[e]=true
          case color_map[v]
            # If it's unvisited it goes into the waiting list
            when :unvisited 
              options.handle_edge(:tree_edge, e)
              color_map[v] = :waiting
              waiting.push(v) 
              # If it's recursive (i.e. dfs) then call self
              gratr_search_iteration(options, waiting, color_map, visited_edges, result, true) if recursive
            when :waiting 
              options.handle_edge(:back_edge, e)
            else 
              options.handle_edge(:forward_edge, e)
          end
        end
        # Finished with this vertex
        options.handle_vertex(:exit_vertex, u)
        color_map[u] = :visited
      end
      
     public
      # Topological Sort Iterator
      #
      # The topological sort algorithm creates a linear ordering of the vertices
      # such that if edge (u,v) appears in the graph, then u comes before v in
      # the ordering. The graph must be a directed acyclic graph (DAG).
      #
      # The iterator can also be applied to undirected graph or to a DG graph
      # which contains a cycle.  In this case, the Iterator does not reach all
      # vertices.  The implementation of acyclic? and cyclic? uses this fact.
      #
      # Can be called with a block as a standard Ruby iterator, or it can
      # be used directly as it will return the result as an Array
      def topsort(start = nil, &block)
        result  = []
        go      = true 
        back    = Proc.new {|e| go = false } 
        push    = Proc.new {|v| result.unshift(v) if go}
        start   ||= vertices[0]
        dfs({:exit_vertex => push, :back_edge => back, :start => start})
        result.each {|v| block.call(v)} if block; result
      end

      # Returns true if a graph contains no cycles, false otherwise
      def acyclic?() topsort.size == size; end

      # Returns false if a graph contains no cycles, true otherwise
      def cyclic?()  not acyclic?; end

      
    end # Search 
  end # Graph
end # GRATR
