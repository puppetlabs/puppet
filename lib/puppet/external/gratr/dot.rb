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
#
# Minimal Dot support, based on Dave Thomas's dot module (included in rdoc).
# rdot.rb is a modified version which also contains support for undirected
# graphs.

require 'puppet/external/gratr/rdot'

module GRATR
  module Graph
 
    # Return a DOT::DOTDigraph for directed graphs or a DOT::DOTSubgraph for an
    # undirected Graph.  _params_ can contain any graph property specified in
    # rdot.rb. If an edge or vertex label is a kind of Hash then the keys
    # which match +dot+ properties will be used as well.
    def to_dot_graph (params = {})
      params['name'] ||= self.class.name.gsub(/:/,'_')
      fontsize   = params['fontsize'] ? params['fontsize'] : '8'
      graph      = (directed? ? DOT::DOTDigraph : DOT::DOTSubgraph).new(params)
      edge_klass = directed? ? DOT::DOTDirectedEdge : DOT::DOTEdge
      vertices.each do |v|
        name = v.to_s
        params = {'name'     => '"'+name+'"',
                  'fontsize' => fontsize,
                  'label'    => name}
        v_label = vertex_label(v)
        params.merge!(v_label) if v_label and v_label.kind_of? Hash
        graph << DOT::DOTNode.new(params)
      end
      edges.each do |e|
        params = {'from'     => '"'+ e.source.to_s + '"',
                  'to'       => '"'+ e.target.to_s + '"',
                  'fontsize' => fontsize }
        e_label = edge_label(e)
        params.merge!(e_label) if e_label and e_label.kind_of? Hash
        graph << edge_klass.new(params)
      end
      graph
    end
    
    # Output the dot format as a string
    def to_dot (params={}) to_dot_graph(params).to_s; end

    # Call +dotty+ for the graph which is written to the file 'graph.dot'
    # in the # current directory.
    def dotty (params = {}, dotfile = 'graph.dot')
      File.open(dotfile, 'w') {|f| f << to_dot(params) }
      system('dotty', dotfile)
    end

    # Use +dot+ to create a graphical representation of the graph.  Returns the
    # filename of the graphics file.
    def write_to_graphic_file (fmt='png', dotfile='graph')
      src = dotfile + '.dot'
      dot = dotfile + '.' + fmt
      
      File.open(src, 'w') {|f| f << self.to_dot << "\n"}
      
      system( "dot -T#{fmt} #{src} -o #{dot}" )
      dot
    end

  end                           # module Graph
end                             # module GRATR
