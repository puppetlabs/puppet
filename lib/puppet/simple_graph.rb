#  Created by Luke A. Kanies on 2007-11-07.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/external/dot'
require 'puppet/relationship'

# A hopefully-faster graph class to replace the use of GRATR.
class Puppet::SimpleGraph
    # An internal class for handling a vertex's edges.
    class VertexWrapper
        attr_accessor :in, :out, :vertex

        # Remove all references to everything.
        def clear
            @adjacencies[:in].clear
            @adjacencies[:out].clear
            @vertex = nil
        end

        def initialize(vertex)
            @vertex = vertex
            @adjacencies = {:in => Hash.new { |h,k| h[k] = [] }, :out => Hash.new { |h,k| h[k] = [] }}
            #@adjacencies = {:in => [], :out => []}
        end

        # Find adjacent vertices or edges.
        def adjacent(options)
            direction = options[:direction] || :out
            options[:type] ||= :vertices

            return @adjacencies[direction].values.flatten if options[:type] == :edges

            return @adjacencies[direction].keys
        end

        # Add an edge to our list.
        def add_edge(direction, edge)
            @adjacencies[direction][other_vertex(direction, edge)] << edge
        end

        # Return all known edges.
        def edges
            [:in, :out].collect { |dir| @adjacencies[dir].values }.flatten
        end

        # Test whether we share an edge with a given vertex.
        def has_edge?(direction, vertex)
            return true if @adjacencies[direction][vertex].length > 0
            return false
        end

        # Create methods for returning the degree and edges.
        [:in, :out].each do |direction|
            # LAK:NOTE If you decide to create methods for directly
            # testing the degree, you'll have to get the values and flatten
            # the results -- you might have duplicate edges, which can give
            # a false impression of what the degree is.  That's just
            # as expensive as just getting the edge list, so I've decided
            # to only add this method.
            define_method("%s_edges" % direction) do
                @adjacencies[direction].values.flatten
            end
        end

        # The other vertex in the edge.
        def other_vertex(direction, edge)
            case direction
            when :in: edge.source
            else
                edge.target
            end
        end

        # Remove an edge from our list.  Assumes that we've already checked
        # that the edge is valid.
        def remove_edge(direction, edge)
            @adjacencies[direction][other_vertex(direction, edge)].delete(edge)
        end

        def to_s
            vertex.to_s
        end
    end

    def initialize
        @vertices = {}
        @edges = []
    end

    # Clear our graph.
    def clear
        @vertices.each { |vertex, wrapper| wrapper.clear }
        @vertices.clear
        @edges.clear
    end

    # Whether our graph is directed.  Always true.  Used to produce dot files.
    def directed?
        true
    end

    # Return a reversed version of this graph.
    def reversal
        result = self.class.new
        vertices.each { |vertex| result.add_vertex(vertex) }
        edges.each do |edge|
            newedge = edge.class.new(edge.target, edge.source, edge.label)
            result.add_edge(newedge)
        end
        result
    end

    # Return the size of the graph.
    def size
        @vertices.length
    end

    # Return the graph as an array.
    def to_a
        @vertices.keys
    end

    # Provide a topological sort.
    def topsort
        degree = {}
        zeros = []
        result = []

        # Collect each of our vertices, with the number of in-edges each has.
        @vertices.each do |name, wrapper|
            edges = wrapper.in_edges
            zeros << wrapper if edges.length == 0
            degree[wrapper.vertex] = edges
        end

        # Iterate over each 0-degree vertex, decrementing the degree of
        # each of its out-edges.
        while wrapper = zeros.pop do
            result << wrapper.vertex
            wrapper.out_edges.each do |edge|
                degree[edge.target].delete(edge)
                zeros << @vertices[edge.target] if degree[edge.target].length == 0
            end
        end

        # If we have any vertices left with non-zero in-degrees, then we've found a cycle.
        if cycles = degree.find_all { |vertex, edges| edges.length > 0 } and cycles.length > 0
            message = cycles.collect { |vertex, edges| edges.collect { |e| e.to_s }.join(", ") }.join(", ")
            raise Puppet::Error, "Found dependency cycles in the following relationships: %s" % message
        end

        return result
    end

    # Add a new vertex to the graph.
    def add_vertex(vertex)
        return false if vertex?(vertex)
        setup_vertex(vertex)
        true # don't return the VertexWrapper instance.
    end

    # Remove a vertex from the graph.
    def remove_vertex!(vertex)
        return nil unless vertex?(vertex)
        @vertices[vertex].edges.each { |edge| remove_edge!(edge) }
        @vertices[vertex].clear
        @vertices.delete(vertex)
    end

    # Test whether a given vertex is in the graph.
    def vertex?(vertex)
        @vertices.include?(vertex)
    end

    # Return a list of all vertices.
    def vertices
        @vertices.keys
    end

    # Add a new edge.  The graph user has to create the edge instance,
    # since they have to specify what kind of edge it is.
    def add_edge(source, target = nil, label = nil)
        if target
            edge = Puppet::Relationship.new(source, target, label)
        else
            edge = source
        end
        [edge.source, edge.target].each { |vertex| setup_vertex(vertex) unless vertex?(vertex) }
        @vertices[edge.source].add_edge :out, edge
        @vertices[edge.target].add_edge :in, edge
        @edges << edge
        true
    end

    # Find a matching edge.  Note that this only finds the first edge,
    # not all of them or whatever.
    def edge(source, target)
        @edges.each_with_index { |test_edge, index| return test_edge if test_edge.source == source and test_edge.target == target }
    end

    def edge_label(source, target)
        return nil unless edge = edge(source, target)
        edge.label
    end

    # Is there an edge between the two vertices?
    def edge?(source, target)
        return false unless vertex?(source) and vertex?(target)

        @vertices[source].has_edge?(:out, target)
    end

    def edges
        @edges.dup
    end

    # Remove an edge from our graph.
    def remove_edge!(edge)
        @vertices[edge.source].remove_edge(:out, edge)
        @vertices[edge.target].remove_edge(:in, edge)
        
        # Here we are looking for an exact edge, so we don't want to use ==, because
        # it's too darn expensive (in testing, deleting 3000 edges went from 6 seconds to
        # 0.05 seconds with this change).
        @edges.each_with_index { |test_edge, index| @edges.delete_at(index) and break if edge.equal?(test_edge) }
        nil
    end

    # Find adjacent edges.
    def adjacent(vertex, options = {})
        return [] unless wrapper = @vertices[vertex]
        return wrapper.adjacent(options)
    end

    private

    # An internal method that skips the validation, so we don't have
    # duplicate validation calls.
    def setup_vertex(vertex)
        @vertices[vertex] = VertexWrapper.new(vertex)
    end
 
    public
    
#    # For some reason, unconnected vertices do not show up in
#    # this graph.
#    def to_jpg(path, name)
#        gv = vertices()
#        Dir.chdir(path) do
#            induced_subgraph(gv).write_to_graphic_file('jpg', name)
#        end
#    end

    def to_yaml_properties
        instance_variables
    end

    # Just walk the tree and pass each edge.
    def walk(source, direction, &block)
        adjacent(source, :direction => direction).each do |target|
            yield source, target
            walk(target, direction, &block)
        end
    end

    # LAK:FIXME This is just a paste of the GRATR code with slight modifications.

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
        v_label = v.to_s
        params.merge!(v_label) if v_label and v_label.kind_of? Hash
        graph << DOT::DOTNode.new(params)
      end
      edges.each do |e|
        params = {'from'     => '"'+ e.source.to_s + '"',
                  'to'       => '"'+ e.target.to_s + '"',
                  'fontsize' => fontsize }
        e_label = e.to_s
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

    # Produce the graph files if requested.
    def write_graph(name)
        return unless Puppet[:graph]

        Puppet.settings.use(:graphing)

        file = File.join(Puppet[:graphdir], "%s.dot" % name.to_s)
        File.open(file, "w") { |f|
            f.puts to_dot("name" => name.to_s.capitalize)
        }
    end
end
