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
    module StrongComponents
      # strong_components computes the strongly connected components
      # of a graph using Tarjan's algorithm based on DFS. See: Robert E. Tarjan
      # _Depth_First_Search_and_Linear_Graph_Algorithms_. SIAM Journal on 
      # Computing, 1(2):146-160, 1972
      #
      # The output of the algorithm is an array of components where is 
      # component is an array of vertices
      #
      # A strongly connected component of a directed graph G=(V,E) is a maximal
      # set of vertices U which is in V such that for every pair of 
      # vertices u and v in U, we have both a path from u to v 
      # and path from v to u. That is to say that u and v are reachable 
      # from each other.
      #
      def strong_components

        dfs_num    = 0
        stack = []; result = []; root = {}; comp = {}; number = {}

        # Enter vertex callback
        enter = Proc.new do |v| 
          root[v] = v
          comp[v] = :new
          number[v] = (dfs_num += 1)
          stack.push(v)
        end

        # Exit vertex callback
        exit  = Proc.new do |v|
          adjacent(v).each do |w|
            if comp[w] == :new
              root[v] = (number[root[v]] < number[root[w]] ? root[v] : root[w])
            end
          end
          if root[v] == v
            component = []
            begin
              w = stack.pop
              comp[w] = :assigned
              component << w
            end until w == v
            result << component
          end
        end

        # Execute depth first search
        dfs({:enter_vertex => enter, :exit_vertex => exit}); result

      end # strong_components
      
      # Returns a condensation graph of the strongly connected components
      # Each node is an array of nodes from the original graph
      def condensation
        sc  = strong_components
        cg  = self.class.new
        map = sc.inject({}) do |a,c| 
          c.each {|v| a[v] = c }; a
        end
        sc.each do |c|
          c.each do |v|
            adjacent(v).each {|v| cg.add_edge!(c, map[v]) unless c == map[v]}
          end
        end; cg
      end

      # Compute transitive closure of a graph. That is any node that is reachable
      # along a path is added as a directed edge.
      def transitive_closure!
        cgtc = condensation.gratr_inner_transitive_closure!
        cgtc.each do |cgv|
          cgtc.adjacent(cgv).each do |adj|
            cgv.each do |u| 
              adj.each {|v| add_edge!(u,v)}  
            end
          end
        end; self
      end

      # This returns the transitive closure of a graph. The original graph
      # is not changed.
      def transitive_closure() self.class.new(self).transitive_closure!; end

     private
      def gratr_inner_transitive_closure!  # :nodoc:
        topsort.reverse.each do |u| 
          adjacent(u).each do |v|
            adjacent(v).each {|w| add_edge!(u,w) unless edge?(u,w)}
          end
        end; self
      end
    end # StrongComponens
    
  end # Graph
end # GRATR
