#--
# Copyright (c) 2006 Shawn Patrick Garbett
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
    module Distance
              
      # Shortest path from Jorgen Band-Jensen and Gregory Gutin,
      # _DIGRAPHS:_Theory,_Algorithms_and_Applications, pg 53-54
      #
      # Requires that the graph be acyclic. If the graph is not
      # acyclic, then see dijkstras_algorithm or bellman_ford_moore
      # for possible solutions.
      #
      # start is the starting vertex 
      # weight can be a Proc, or anything else is accessed using the [] for the
      #     the label or it defaults to using
      #     the value stored in the label for the Edge. If it is a Proc it will 
      #     pass the edge to the proc and use the resulting value.
      # zero is used for math system with a different definition of zero
      #
      # Returns a hash with the key being a vertex and the value being the
      # distance. A missing vertex from the hash is an infinite distance
      #
      # Complexity O(n+m)
      def shortest_path(start, weight=nil, zero=0)
        dist = {start => zero}; path = {}
        topsort(start) do |vi|
          next if vi == start
          dist[vi],path[vi] = adjacent(vi, :direction => :in).map do |vj|
            [dist[vj] + cost(vj,vi,weight), vj] 
          end.min {|a,b| a[0] <=> b[0]}
        end; 
        dist.keys.size == vertices.size ? [dist,path] : nil
      end # shortest_path    
    
      # Algorithm from Jorgen Band-Jensen and Gregory Gutin,
      # _DIGRAPHS:_Theory,_Algorithms_and_Applications, pg 53-54
      #  
      # Finds the distances from a given vertex s in a weighted digraph
      # to the rest of the vertices, provided all the weights of arcs
      # are non-negative. If negative arcs exist in the graph, two 
      # basic options exist, 1) modify all weights to be positive by
      # using an offset, or 2) use the bellman_ford_moore algorithm.
      # Also if the graph is acyclic, use the shortest_path algorithm.
      #
      # weight can be a Proc, or anything else is accessed using the [] for the
      #     the label or it defaults to using
      #     the value stored in the label for the Edge. If it is a Proc it will 
      #     pass the edge to the proc and use the resulting value.
      #  
      # zero is used for math system with a different definition of zero
      #
      # Returns a hash with the key being a vertex and the value being the
      # distance. A missing vertex from the hash is an infinite distance
      #
      # O(n*log(n) + m) complexity
      def dijkstras_algorithm(s, weight = nil, zero = 0)
        q = vertices; distance = { s => zero }; path = {}
        while not q.empty?
          v = (q & distance.keys).inject(nil) {|a,k| (!a.nil?) && (distance[a] < distance[k]) ? a : k} 
          q.delete(v)
          (q & adjacent(v)).each do |u|
            c = cost(v,u,weight)
            if distance[u].nil? or distance[u] > (c+distance[v])
              distance[u] = c + distance[v]
              path[u] = v
            end
          end
        end; [distance, path]
      end # dijkstras_algorithm

      # Algorithm from Jorgen Band-Jensen and Gregory Gutin,
      # _DIGRAPHS:_Theory,_Algorithms_and_Applications, pg 56-58
      #  
      # Finds the distances from a given vertex s in a weighted digraph
      # to the rest of the vertices, provided the graph has no negative cycle.
      # If no negative weights exist, then dijkstras_algorithm is more
      # efficient in time and space. Also if the graph is acyclic, use the
      # shortest_path algorithm.
      #
      # weight can be a Proc, or anything else is accessed using the [] for the
      #     the label or it defaults to using
      #     the value stored in the label for the Edge. If it is a Proc it will 
      #     pass the edge to the proc and use the resulting value.
      #  
      # zero is used for math system with a different definition of zero
      #
      # Returns a hash with the key being a vertex and the value being the
      # distance. A missing vertex from the hash is an infinite distance
      #
      # O(nm) complexity   
      def bellman_ford_moore(start, weight = nil, zero = 0)
        distance = { start => zero }; path = {}
        2.upto(vertices.size) do
          edges.each do |e|
            u,v = e[0],e[1]
            unless distance[u].nil?
              c = cost(u, v, weight)+distance[u]
              if distance[v].nil? or c < distance[v]
                distance[v] = c
                path[v] = u
              end 
            end        
          end
        end; [distance, path]
      end # bellman_ford_moore
    
      # This uses the Floyd-Warshall algorithm to efficiently find
      # and record shortest paths at the same time as establishing
      # the costs for all vertices in a graph.
      # See, S.Skiena, "The Algorithm Design Manual", 
      # Springer Verlag, 1998 for more details.
      #  
      # Returns a pair of matrices and a hash of delta values. 
      # The matrices will be indexed by two vertices and are
      # implemented as a Hash of Hashes. The first matrix is the cost, the second
      # matrix is the shortest path spanning tree. The delta (difference of number
      # of in edges and out edges) is indexed by vertex.
      #
      # weight specifies how an edge weight is determined, if it's a
      # Proc the Edge is passed to it, if it's nil it will just use
      # the value in the label for the Edge, otherwise the weight is
      # determined by applying the [] operator to the value in the 
      # label for the Edge
      #
      # zero defines the zero value in the math system used. Defaults
      # of course, to 0. This allows for no assumptions to be made
      # about the math system and fully functional duck typing.
      #
      # O(n^3) complexity in time.
      def floyd_warshall(weight=nil, zero=0)
        c     = Hash.new {|h,k| h[k] = Hash.new}
        path  = Hash.new {|h,k| h[k] = Hash.new}
        delta = Hash.new {|h,k| h[k] = 0}
        edges.each do |e| 
          delta[e.source] += 1
          delta[e.target] -= 1
          path[e.source][e.target] = e.target      
          c[e.source][e.target] = cost(e, weight)
        end
        vertices.each do |k|
          vertices.each do |i|
            if c[i][k]
              vertices.each do |j|
                if c[k][j] && 
                  (c[i][j].nil? or c[i][j] > (c[i][k] + c[k][j]))
                  path[i][j] = path[i][k]
                  c[i][j] = c[i][k] + c[k][j]
                  return nil if i == j and c[i][j] < zero
                end
              end
            end  
          end
        end
        [c, path, delta]
      end # floyd_warshall
           
    end # Distance
  end # Graph
end # GRATR