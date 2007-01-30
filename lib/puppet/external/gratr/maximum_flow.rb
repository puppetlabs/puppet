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

    module MaximumFlow

      # Maximum flow, it returns an array with the maximum flow and a hash of flow per edge
      # Currently a highly inefficient implementation, FIXME, This should use Goldberg and Tarjan's method.
      def maximum_flow(s, t, capacity = nil, zero = 0)
        flow       = Hash.new(zero)
        available  = Hash.new(zero)
        total      = zero
        edges.each {|e| available[e] = cost(e,capacity)} 
        adj_positive = Proc.new do |u|
          adjacent(u).select {|r| available[edge_class[u,r]] > zero}
        end
        while (tree = bfs_tree_from_vertex(start))[t]
          route = [t]
          while route[-1] != s
            route << tree[route[route[-1]]]
            raise ArgumentError, "No route from #{s} to #{t} possible"
          end; route.reverse
          amt   = route.map {|e| available[e]}.min
          route.each do |e|
            flow[e]      += amt
            available[e] -= amt
          end
          total += amt
        end
        
        [total, flow]
      end

    end # MaximumFlow
  end # Graph
end # GRATR