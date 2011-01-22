#  Created by Luke A. Kanies on 2007-11-07.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/external/dot'
require 'puppet/relationship'
require 'set'

# A hopefully-faster graph class to replace the use of GRATR.
class Puppet::SimpleGraph
  #
  # All public methods of this class must maintain (assume ^ ensure) the following invariants, where "=~=" means
  # equiv. up to order:
  #
  #   @in_to.keys =~= @out_to.keys =~= all vertices
  #   @in_to.values.collect { |x| x.values }.flatten =~= @out_from.values.collect { |x| x.values }.flatten =~= all edges
  #   @in_to[v1][v2] =~= @out_from[v2][v1] =~= all edges from v1 to v2
  #   @in_to   [v].keys =~= vertices with edges leading to   v
  #   @out_from[v].keys =~= vertices with edges leading from v
  #   no operation may shed reference loops (for gc)
  #   recursive operation must scale with the depth of the spanning trees, or better (e.g. no recursion over the set
  #       of all vertices, etc.)
  #
  # This class is intended to be used with DAGs.  However, if the
  # graph has a cycle, it will not cause non-termination of any of the
  # algorithms.  The topsort method detects and reports cycles.
  #
  def initialize
    @in_to = {}
    @out_from = {}
    @upstream_from = {}
    @downstream_from = {}
  end

  # Clear our graph.
  def clear
    @in_to.clear
    @out_from.clear
    @upstream_from.clear
    @downstream_from.clear
  end

  # Which resources depend upon the given resource.
  def dependencies(resource)
    vertex?(resource) ? upstream_from_vertex(resource).keys : []
  end

  def dependents(resource)
    vertex?(resource) ? downstream_from_vertex(resource).keys : []
  end

  # Whether our graph is directed.  Always true.  Used to produce dot files.
  def directed?
    true
  end

  # Determine all of the leaf nodes below a given vertex.
  def leaves(vertex, direction = :out)
    tree_from_vertex(vertex, direction).keys.find_all { |c| adjacent(c, :direction => direction).empty? }
  end

  # Collect all of the edges that the passed events match.  Returns
  # an array of edges.
  def matching_edges(event, base = nil)
    source = base || event.resource

    unless vertex?(source)
      Puppet.warning "Got an event from invalid vertex #{source.ref}"
      return []
    end
    # Get all of the edges that this vertex should forward events
    # to, which is the same thing as saying all edges directly below
    # This vertex in the graph.
    @out_from[source].values.flatten.find_all { |edge| edge.match?(event.name) }
  end

  # Return a reversed version of this graph.
  def reversal
    result = self.class.new
    vertices.each { |vertex| result.add_vertex(vertex) }
    edges.each do |edge|
      result.add_edge edge.class.new(edge.target, edge.source, edge.label)
    end
    result
  end

  # Return the size of the graph.
  def size
    vertices.size
  end

  def to_a
    vertices
  end

  # Provide a topological sort with cycle reporting
  def topsort_with_cycles
    degree = {}
    zeros = []
    result = []

    # Collect each of our vertices, with the number of in-edges each has.
    vertices.each do |v|
      edges = @in_to[v].dup
      zeros << v if edges.empty?
      degree[v] = edges
    end

    # Iterate over each 0-degree vertex, decrementing the degree of
    # each of its out-edges.
    while v = zeros.pop
      result << v
      @out_from[v].each { |v2,es|
        degree[v2].delete(v)
        zeros << v2 if degree[v2].empty?
      }
    end

    # If we have any vertices left with non-zero in-degrees, then we've found a cycle.
    if cycles = degree.values.reject { |ns| ns.empty? } and cycles.length > 0
      message = cycles.collect { |edges|
        '(' + edges.collect { |e| e[1].to_s }.join(", ") + ')'
      }.join("\n")
      raise Puppet::Error, "Found dependency cycles in the following relationships:\n" +
        message + "\n" +
        "Try the '--graph' option and opening the '.dot' file in OmniGraffle or GraphViz"
    end

    result
  end

  # Provide a topological sort.
  def topsort
    degree = {}
    zeros = []
    result = []

    # Collect each of our vertices, with the number of in-edges each has.
    vertices.each do |v|
      edges = @in_to[v]
      zeros << v if edges.empty?
      degree[v] = edges.length
    end

    # Iterate over each 0-degree vertex, decrementing the degree of
    # each of its out-edges.
    while v = zeros.pop
      result << v
      @out_from[v].each { |v2,es|
        zeros << v2 if (degree[v2] -= 1) == 0
      }
    end

    # If we have any vertices left with non-zero in-degrees, then we've found a cycle.
    if cycles = degree.values.reject { |ns| ns == 0  } and cycles.length > 0
      topsort_with_cycles
    end

    result
  end

  # Add a new vertex to the graph.
  def add_vertex(vertex)
    @in_to[vertex]    ||= {}
    @out_from[vertex] ||= {}
  end

  # Remove a vertex from the graph.
  def remove_vertex!(v)
    return unless vertex?(v)
    @upstream_from.clear
    @downstream_from.clear
    (@in_to[v].values+@out_from[v].values).flatten.each { |e| remove_edge!(e) }
    @in_to.delete(v)
    @out_from.delete(v)
  end

  # Test whether a given vertex is in the graph.
  def vertex?(v)
    @in_to.include?(v)
  end

  # Return a list of all vertices.
  def vertices
    @in_to.keys
  end

  # Add a new edge.  The graph user has to create the edge instance,
  # since they have to specify what kind of edge it is.
  def add_edge(e,*a)
    return add_relationship(e,*a) unless a.empty?
    @upstream_from.clear
    @downstream_from.clear
    add_vertex(e.source)
    add_vertex(e.target)
    @in_to[   e.target][e.source] ||= []; @in_to[   e.target][e.source] |= [e]
    @out_from[e.source][e.target] ||= []; @out_from[e.source][e.target] |= [e]
  end

  def add_relationship(source, target, label = nil)
    add_edge Puppet::Relationship.new(source, target, label)
  end

  # Find all matching edges.
  def edges_between(source, target)
    (@out_from[source] || {})[target] || []
  end

  # Is there an edge between the two vertices?
  def edge?(source, target)
    vertex?(source) and vertex?(target) and @out_from[source][target]
  end

  def edges
    @in_to.values.collect { |x| x.values }.flatten
  end

  def each_edge
    @in_to.each { |t,ns| ns.each { |s,es| es.each { |e| yield e }}}
  end

  # Remove an edge from our graph.
  def remove_edge!(e)
    if edge?(e.source,e.target)
      @upstream_from.clear
      @downstream_from.clear
      @in_to   [e.target].delete e.source if (@in_to   [e.target][e.source] -= [e]).empty?
      @out_from[e.source].delete e.target if (@out_from[e.source][e.target] -= [e]).empty?
    end
  end

  # Find adjacent edges.
  def adjacent(v, options = {})
    return [] unless ns = (options[:direction] == :in) ? @in_to[v] : @out_from[v]
    (options[:type] == :edges) ? ns.values.flatten : ns.keys
  end
  
  # Take container information from another graph and use it
  # to replace any container vertices with their respective leaves.
  # This creates direct relationships where there were previously
  # indirect relationships through the containers.
  def splice!(other, type)
    # We have to get the container list via a topological sort on the
    # configuration graph, because otherwise containers that contain
    # other containers will add those containers back into the
    # graph.  We could get a similar affect by only setting relationships
    # to container leaves, but that would result in many more
    # relationships.
    stage_class = Puppet::Type.type(:stage)
    whit_class  = Puppet::Type.type(:whit)
    containers = other.topsort.find_all { |v| (v.is_a?(type) or v.is_a?(stage_class)) and vertex?(v) }
    containers.each do |container|
      # Get the list of children from the other graph.
      children = other.adjacent(container, :direction => :out)

      # MQR TODO: Luke suggests that it should be possible to refactor the system so that
      #           container nodes are retained, thus obviating the need for the whit. 
      children = [whit_class.new(:name => container.name, :catalog => other)] if children.empty?

      # First create new edges for each of the :in edges
      [:in, :out].each do |dir|
        edges = adjacent(container, :direction => dir, :type => :edges)
        edges.each do |edge|
          children.each do |child|
            if dir == :in
              s = edge.source
              t = child
            else
              s = child
              t = edge.target
            end

            add_edge(s, t, edge.label)
          end

          # Now get rid of the edge, so remove_vertex! works correctly.
          remove_edge!(edge)
        end
      end
      remove_vertex!(container)
    end
  end

  # Just walk the tree and pass each edge.
  def walk(source, direction)
    # Use an iterative, breadth-first traversal of the graph. One could do
    # this recursively, but Ruby's slow function calls and even slower
    # recursion make the shorter, recursive algorithm cost-prohibitive.
    stack = [source]
    seen = Set.new
    until stack.empty?
      node = stack.shift
      next if seen.member? node
      connected = adjacent(node, :direction => direction)
      connected.each do |target|
        yield node, target
      end
      stack.concat(connected)
      seen << node
    end
  end

  # A different way of walking a tree, and a much faster way than the
  # one that comes with GRATR.
  def tree_from_vertex(start, direction = :out)
    predecessor={}
    walk(start, direction) do |parent, child|
      predecessor[child] = parent
    end
    predecessor
  end

  def downstream_from_vertex(v)
    return @downstream_from[v] if @downstream_from[v]
    result = @downstream_from[v] = {}
    @out_from[v].keys.each do |node|
      result[node] = 1
      result.update(downstream_from_vertex(node))
    end
    result
  end

  def upstream_from_vertex(v)
    return @upstream_from[v] if @upstream_from[v]
    result = @upstream_from[v] = {}
    @in_to[v].keys.each do |node|
      result[node] = 1
      result.update(upstream_from_vertex(node))
    end
    result
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

  # Produce the graph files if requested.
  def write_graph(name)
    return unless Puppet[:graph]

    Puppet.settings.use(:graphing)

    file = File.join(Puppet[:graphdir], "#{name}.dot")
    File.open(file, "w") { |f|
      f.puts to_dot("name" => name.to_s.capitalize)
    }
  end

  # This flag may be set to true to use the new YAML serialzation
  # format (where @vertices is a simple list of vertices rather than a
  # list of VertexWrapper objects).  Deserialization supports both
  # formats regardless of the setting of this flag.
  class << self
    attr_accessor :use_new_yaml_format
  end
  self.use_new_yaml_format = false

  # Stub class to allow graphs to be represented in YAML using the old
  # (version 2.6) format.
  class VertexWrapper
    attr_reader :vertex, :adjacencies
    def initialize(vertex, adjacencies)
      @vertex = vertex
      @adjacencies = adjacencies
    end

    def inspect
      { :@adjacencies => @adjacencies, :@vertex => @vertex.to_s }.inspect
    end
  end

  # instance_variable_get is used by Object.to_zaml to get instance
  # variables.  Override it so that we can simulate the presence of
  # instance variables @edges and @vertices for serialization.
  def instance_variable_get(v)
    case v.to_s
    when '@edges' then
      edges
    when '@vertices' then
      if self.class.use_new_yaml_format
        vertices
      else
        result = {}
        vertices.each do |vertex|
          adjacencies = {}
          [:in, :out].each do |direction|
            adjacencies[direction] = {}
            adjacent(vertex, :direction => direction, :type => :edges).each do |edge|
              other_vertex = direction == :in ? edge.source : edge.target
              (adjacencies[direction][other_vertex] ||= Set.new).add(edge)
            end
          end
          result[vertex] = Puppet::SimpleGraph::VertexWrapper.new(vertex, adjacencies)
        end
        result
      end
    else
      super(v)
    end
  end

  def to_yaml_properties
    other_vars = instance_variables.reject { |v| %w{@in_to @out_from @upstream_from @downstream_from}.include?(v) }
    (other_vars + %w{@vertices @edges}).sort.uniq
  end

  def yaml_initialize(tag, var)
    initialize()
    vertices = var.delete('vertices')
    edges = var.delete('edges')
    if vertices.is_a?(Hash)
      # Support old (2.6) format
      vertices = vertices.keys
    end
    vertices.each { |v| add_vertex(v) }
    edges.each { |e| add_edge(e) }
    var.each do |varname, value|
      instance_variable_set("@#{varname}", value)
    end
  end
end
