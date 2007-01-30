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


require 'puppet/external/gratr/edge'
require 'puppet/external/gratr/graph'

module GRATR
  # This class defines a cycle graph of size n
  # This is easily done by using the base Graph
  # class and implemeting the minimum methods needed to
  # make it work. This is a good example to look
  # at for making one's own graph classes
  class Cycle
    
    def initialize(n) @size = n;       end
    def directed?()     false;           end
    def vertices()    (1..@size).to_a; end
    def vertex?(v)    v > 0 and v <= @size; end
    def edge?(u,v=nil)
      u, v = [u.source, v.target] if u.kind_of? GRATR::Edge
      vertex?(u) && vertex?(v) && ((v-u == 1) or (u==@size && v=1))
    end
    def edges() Array.new(@size) {|i| GRATR::UndirectedEdge[i+1, (i+1)==@size ? 1 : i+2]}; end
  end
  
  # This class defines a complete graph of size n
  # This is easily done by using the base Graph
  # class and implemeting the minimum methods needed to
  # make it work. This is a good example to look
  # at for making one's own graph classes
  class Complete < Cycle
    def initialize(n) @size = n; @edges = nil; end
    def edges
      return @edges if @edges      # Cache edges
      @edges = []
      @size.times do |u|
        @size.times {|v| @edges << GRATR::UndirectedEdge[u+1, v+1]}
      end; @edges
    end
    def edge?(u,v=nil)
      u, v = [u.source, v.target] if u.kind_of? GRATR::Edge
      vertex?(u) && vertex?(v)
    end
  end              # Complete
  
  
  
end                # GRATR
