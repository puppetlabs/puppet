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


require 'set'

module GRATR
  module Graph    
    # Biconnected is a module for adding the biconnected algorithm to 
    # UndirectedGraphs
    module Biconnected

      # biconnected computes the biconnected subgraphs
      # of a graph using Tarjan's algorithm based on DFS. See: Robert E. Tarjan
      # _Depth_First_Search_and_Linear_Graph_Algorithms_. SIAM Journal on 
      # Computing, 1(2):146-160, 1972
      #
      # The output of the algorithm is a pair, the first value is an 
      # array of biconnected subgraphs. The second is the set of
      # articulation vertices.
      #
      # A connected graph is biconnected if the removal of any single vertex 
      # (and all edges incident on that vertex) cannot disconnect the graph.
      # More generally, the biconnected components of a graph are the maximal
      # subsets of vertices such that the removal of a vertex from a particular
      # component will not disconnect the component. Unlike connected components,
      # vertices may belong to multiple biconnected components: those vertices
      # that belong to more than one biconnected component are called articulation
      # points or, equivalently, cut vertices. Articulation points are vertices
      # whose removal would increase the number of connected components in the graph.
      # Thus, a graph without articulation points is biconnected.
      def biconnected
        dfs_num     = 0
        number      = {}; predecessor = {}; low_point   = {}
        stack       = []; result      = []; articulation= []

        root_vertex  = Proc.new {|v| predecessor[v]=v }
        enter_vertex = Proc.new {|u| number[u]=low_point[u]=(dfs_num+=1) }
        tree_edge  = Proc.new do |e|
          stack.push(e)
          predecessor[e.target] = e.source
        end
        back_edge  = Proc.new do |e|
          if e.target != predecessor[e.source]
            stack.push(e)
            low_point[e.source] = [low_point[e.source], number[e.target]].min
          end
        end
        exit_vertex = Proc.new do |u|
          parent = predecessor[u]
          is_articulation_point = false
          if number[parent] > number[u]
            parent = predecessor[parent]
            is_articulation_point = true
          end
          if parent == u
            is_articulation_point = false if (number[u] + 1) == number[predecessor[u]]
          else
            low_point[parent] = [low_point[parent], low_point[u]].min
            if low_point[u] >= number[parent]
              if number[parent] > number[predecessor[parent]]
                predecessor[u] = predecessor[parent]
                predecessor[parent] = u
              end
              result << (component = self.class.new)
              while number[stack[-1].source] >= number[u]
                component.add_edge!(stack.pop)
              end
              component.add_edge!(stack.pop)
              if stack.empty?
                predecessor[u] = parent
                predecessor[parent] = u
              end
            end
          end
          articulation << u if is_articulation_point
        end

        # Execute depth first search
        dfs({:root_vertex  => root_vertex,
             :enter_vertex => enter_vertex, 
             :tree_edge    => tree_edge,
             :back_edge    => back_edge,
             :exit_vertex  => exit_vertex})
           
        [result, articulation]
      end # biconnected

    end # Biconnected

  end # Graph
end # GRATR
