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
    module Comparability
      
      # A comparability graph is an UndirectedGraph that has a transitive
      # orientation. This returns a boolean that says if this graph
      # is a comparability graph.
      def comparability?() gamma_decomposition[1]; end
      
      # Returns an array with two values, the first being a hash of edges 
      # with a number containing their class assignment, the second valud
      # is a boolean which states whether or not the graph is a 
      # comparability graph
      #
      # Complexity in time O(d*|E|) where d is the maximum degree of a vertex
      # Complexity in space O(|V|+|E|)
      def gamma_decomposition
        k = 0; comparability=true; classification={}
        edges.map {|edge| [edge.source,edge.target]}.each do |e|
          if classification[e].nil?
            k += 1
            classification[e] = k; classification[e.reverse] = -k
            comparability &&= gratr_comparability_explore(e, k, classification)
          end
        end; [classification, comparability]
      end
      
      # Returns one of the possible transitive orientations of 
      # the UndirectedGraph as a Digraph
      def transitive_orientation(digraph_class=Digraph)
        raise NotImplementError
      end
      
     private
     
      # Taken from Figure 5.10, on pg. 130 of Martin Golumbic's, _Algorithmic_Graph_
      # _Theory_and_Perfect_Graphs.
      def gratr_comparability_explore(edge, k, classification, space='')
        ret = gratr_comparability_explore_inner(edge, k, classification, :forward, space)
        gratr_comparability_explore_inner(edge.reverse, k, classification, :backward, space) && ret
      end
      
      def gratr_comparability_explore_inner(edge, k, classification, direction,space)
        comparability = true  
        adj_target = adjacent(edge[1])
        adjacent(edge[0]).select do |mt|
          (classification[[edge[1],mt]] || k).abs < k or
          not adj_target.any? {|adj_t| adj_t == mt} 
        end.each do |m|
          e = (direction == :forward) ? [edge[0], m] : [m,edge[0]]
          if classification[e].nil?
            classification[e] = k
            classification[e.reverse] = -k
            comparability = gratr_comparability_explore(e, k, classification, '  '+space) && comparability
          elsif classification[e] == -k
            classification[e] = k
            gratr_comparability_explore(e, k, classification, '  '+space)
            comparability = false
          end
        end; comparability
      end # gratr_comparability_explore_inner
      
    end # Comparability
  end # Graph
end # GRATR