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
  module Labels
    # Return a label for an edge or vertex
    def [](u) (u.kind_of? GRATR::Edge) ? edge_label(u) : vertex_label(u); end

    # Set a label for an edge or vertex
    def []= (u, value) (u.kind_of? GRATR::Edge) ? edge_label_set(u,value) : vertex_label_set(u, value); end

    # Delete a label entirely
    def delete_label(u) (u.kind_of? GRATR::Edge) ? edge_label_delete(u) : vertex_label_delete(u); end

    # Get the label for an edge
    def vertex_label(v)        vertex_label_dict[v]; end

    # Set the label for an edge
    def vertex_label_set(v, l) vertex_label_dict[v] = l; self; end

    # Get the label for an edge
    def edge_label(u,v=nil,n=nil)
      u = edge_convert(u,v,n)
      edge_label_dict[u]
    end

    # Set the label for an edge
    def edge_label_set(u, v=nil, l=nil, n=nil) 
      u.kind_of?(GRATR::Edge) ? l = v : u = edge_convert(u,v,n)
      edge_label_dict[u] = l; self
    end

    # Delete all graph labels
    def clear_all_labels()  @vertex_labels = {}; @edge_labels = {}; end

    # Delete an edge label
    def edge_label_delete(u, v=nil, n=nil)
      u = edge_convert(u,v,n)
      edge_label_dict.delete(u)
    end

    # Delete a vertex label
    def vertex_label_delete(v) vertex_label_dict.delete(v); end

   protected

    def vertex_label_dict() @vertex_labels ||= {}; end
    def edge_label_dict()   @edge_labels   ||= {}; end

    # A generic cost function. It either calls the weight function with and edge
    # constructed from the two nodes, or calls the [] operator of the label
    # when given a value. If no weight value is specified, the label itself is
    # treated as the cost value.
    #
    # Note: This function will not work for Pseudo or Multi graphs at present. 
    def cost(u,v=nil,weight=nil)
      u.kind_of?(Edge) ? weight = v : u = edge_class[u,v] 
      case weight
        when Proc : weight.call(u)
        when nil  : self[u]
        else        self[u][weight]
      end
    end

  end
end
