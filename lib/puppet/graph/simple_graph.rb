require 'puppet/external/dot'
require 'puppet/relationship'
require 'set'

# A hopefully-faster graph class to replace the use of GRATR.
class Puppet::Graph::SimpleGraph
  include Puppet::Util::PsychSupport

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
  # algorithms.
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
      Puppet.warning _("Got an event from invalid vertex %{source}") % { source: source.ref }
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

  # This is a simple implementation of Tarjan's algorithm to find strongly
  # connected components in the graph; this is a fairly ugly implementation,
  # because I can't just decorate the vertices themselves.
  #
  # This method has an unhealthy relationship with the find_cycles_in_graph
  # method below, which contains the knowledge of how the state object is
  # maintained.
  def tarjan(root, s)
    # initialize the recursion stack we use to work around the nasty lack of a
    # decent Ruby stack.
    recur = [{ :node => root }]

    while not recur.empty? do
      frame = recur.last
      vertex = frame[:node]

      case frame[:step]
      when nil then
        s[:index][vertex]   = s[:number]
        s[:lowlink][vertex] = s[:number]
        s[:number]          = s[:number] + 1

        s[:stack].push(vertex)
        s[:seen][vertex] = true

        frame[:children] = adjacent(vertex)
        frame[:step]     = :children

      when :children then
        if frame[:children].length > 0 then
          child = frame[:children].shift
          if ! s[:index][child] then
            # Never seen, need to recurse.
            frame[:step] = :after_recursion
            frame[:child] = child
            recur.push({ :node => child })
          elsif s[:seen][child] then
            s[:lowlink][vertex] = [s[:lowlink][vertex], s[:index][child]].min
          end
        else
          if s[:lowlink][vertex] == s[:index][vertex] then
            this_scc = []
            begin
              top = s[:stack].pop
              s[:seen][top] = false
              this_scc << top
            end until top == vertex
            s[:scc] << this_scc
          end
          recur.pop               # done with this node, finally.
        end

      when :after_recursion then
        s[:lowlink][vertex] = [s[:lowlink][vertex], s[:lowlink][frame[:child]]].min
        frame[:step] = :children

      else
        fail "#{frame[:step]} is an unknown step"
      end
    end
  end

  # Find all cycles in the graph by detecting all the strongly connected
  # components, then eliminating everything with a size of one as
  # uninteresting - which it is, because it can't be a cycle. :)
  #
  # This has an unhealthy relationship with the 'tarjan' method above, which
  # it uses to implement the detection of strongly connected components.
  def find_cycles_in_graph
    state = {
      :number => 0, :index => {}, :lowlink => {}, :scc => [],
      :stack => [], :seen => {}
    }

    # we usually have a disconnected graph, must walk all possible roots
    vertices.each do |vertex|
      if ! state[:index][vertex] then
        tarjan vertex, state
      end
    end

    # To provide consistent results to the user, given that a hash is never
    # assured to return the same order, and given our graph processing is
    # based on hash tables, we need to sort the cycles internally, as well as
    # the set of cycles.
    #
    # Given we are in a failure state here, any extra cost is more or less
    # irrelevant compared to the cost of a fix - which is on a human
    # time-scale.
    state[:scc].select do |component|
      multi_vertex_component?(component) || single_vertex_referring_to_self?(component)
    end.map do |component|
      component.sort
    end.sort
  end

  # Perform a BFS on the sub graph representing the cycle, with a view to
  # generating a sufficient set of paths to report the cycle meaningfully, and
  # ideally usefully, for the end user.
  #
  # BFS is preferred because it will generally report the shortest paths
  # through the graph first, which are more likely to be interesting to the
  # user.  I think; it would be interesting to verify that. --daniel 2011-01-23
  def paths_in_cycle(cycle, max_paths = 1)
    #TRANSLATORS "negative or zero" refers to the count of paths
    raise ArgumentError, _("negative or zero max_paths") if max_paths < 1

    # Calculate our filtered outbound vertex lists...
    adj = {}
    cycle.each do |vertex|
      adj[vertex] = adjacent(vertex).select{|s| cycle.member? s}
    end

    found = []

    # frame struct is vertex, [path]
    stack = [[cycle.first, []]]
    while frame = stack.shift do
      if frame[1].member?(frame[0]) then
        found << frame[1] + [frame[0]]
        break if found.length >= max_paths
      else
        adj[frame[0]].each do |to|
          stack.push [to, frame[1] + [frame[0]]]
        end
      end
    end

    return found.sort
  end

  # @return [Array] array of dependency cycles (arrays)
  def report_cycles_in_graph
    cycles = find_cycles_in_graph
    number_of_cycles = cycles.length
    return if number_of_cycles == 0

    message = n_("Found %{num} dependency cycle:\n", "Found %{num} dependency cycles:\n", number_of_cycles) % { num: number_of_cycles }

    cycles.each do |cycle|
      paths = paths_in_cycle(cycle)
      message += paths.map{ |path| '(' + path.join(' => ') + ')'}.join('\n') + '\n'
    end

    if Puppet[:graph] then
      filename = write_cycles_to_graph(cycles)
      message += _("Cycle graph written to %{filename}.") % { filename: filename }
    else
      #TRANSLATORS '--graph' refers to a command line option and OmniGraffle and GraphViz are program names and should not be translated
      message += _("Try the '--graph' option and opening the resulting '.dot' file in OmniGraffle or GraphViz")
    end
    Puppet.err(message)
    cycles
  end

  def write_cycles_to_graph(cycles)
    # This does not use the DOT graph library, just writes the content
    # directly.  Given the complexity of this, there didn't seem much point
    # using a heavy library to generate exactly the same content. --daniel 2011-01-27
    graph = ["digraph Resource_Cycles {"]
    graph << '  label = "Resource Cycles"'

    cycles.each do |cycle|
      paths_in_cycle(cycle, 10).each do |path|
        graph << path.map { |v| '"' + v.to_s.gsub(/"/, '\\"') + '"' }.join(" -> ")
      end
    end

    graph << '}'

    filename = File.join(Puppet[:graphdir], "cycles.dot")
    # DOT files are assumed to be UTF-8 by default - http://www.graphviz.org/doc/info/lang.html
    File.open(filename, "w:UTF-8") { |f| f.puts graph }
    return filename
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
    e = Puppet::Relationship.from_data_hash(e) if e.is_a?(Hash)
    @upstream_from.clear
    @downstream_from.clear
    add_vertex(e.source)
    add_vertex(e.target)
    # Avoid multiple lookups here. This code is performance critical
    arr = (@in_to[e.target][e.source] ||= [])
    arr << e unless arr.include?(e)
    arr = (@out_from[e.source][e.target] ||= [])
    arr << e unless arr.include?(e)
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

  def direct_dependents_of(v)
    (@out_from[v] || {}).keys
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

  def direct_dependencies_of(v)
    (@in_to[v] || {}).keys
  end

  # Return an array of the edge-sets between a series of n+1 vertices (f=v0,v1,v2...t=vn)
  #   connecting the two given vertices.  The ith edge set is an array containing all the
  #   edges between v(i) and v(i+1); these are (by definition) never empty.
  #
  #     * if f == t, the list is empty
  #     * if they are adjacent the result is an array consisting of
  #       a single array (the edges from f to t)
  #     * and so on by induction on a vertex m between them
  #     * if there is no path from f to t, the result is nil
  #
  # This implementation is not particularly efficient; it's used in testing where clarity
  #   is more important than last-mile efficiency.
  #
  def path_between(f,t)
    if f==t
      []
    elsif direct_dependents_of(f).include?(t)
      [edges_between(f,t)]
    elsif dependents(f).include?(t)
      m = (dependents(f) & direct_dependencies_of(t)).first
      path_between(f,m) + path_between(m,t)
    else
      nil
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
      name = v.ref
      params = {'name'     => '"'+name+'"',
        'fontsize' => fontsize,
        'label'    => name}
      v_label = v.ref
      params.merge!(v_label) if v_label and v_label.kind_of? Hash
      graph << DOT::DOTNode.new(params)
    end
    edges.each do |e|
      params = {'from'     => '"'+ e.source.ref + '"',
        'to'       => '"'+ e.target.ref + '"',
        'fontsize' => fontsize }
      e_label = e.ref
      params.merge!(e_label) if e_label and e_label.kind_of? Hash
      graph << edge_klass.new(params)
    end
    graph
  end

  # Output the dot format as a string
  def to_dot (params={}) to_dot_graph(params).to_s; end

  # Produce the graph files if requested.
  def write_graph(name)
    return unless Puppet[:graph]

    file = File.join(Puppet[:graphdir], "#{name}.dot")
    # DOT files are assumed to be UTF-8 by default - http://www.graphviz.org/doc/info/lang.html
    File.open(file, "w:UTF-8") { |f|
      f.puts to_dot("name" => name.to_s.capitalize)
    }
  end

  # This flag may be set to true to use the new YAML serialization
  # format (where @vertices is a simple list of vertices rather than a
  # list of VertexWrapper objects).  Deserialization supports both
  # formats regardless of the setting of this flag.
  class << self
    attr_accessor :use_new_yaml_format
  end
  self.use_new_yaml_format = false

  def initialize_from_hash(hash)
    initialize
    vertices = hash['vertices']
    edges = hash['edges']
    if vertices.is_a?(Hash)
      # Support old (2.6) format
      vertices = vertices.keys
    end
    vertices.each { |v| add_vertex(v) } unless vertices.nil?
    edges.each { |e| add_edge(e) } unless edges.nil?
  end

  def to_data_hash
    hash = { 'edges' => edges.map(&:to_data_hash) }
    hash['vertices'] = if self.class.use_new_yaml_format
      vertices
    else
      # Represented in YAML using the old (version 2.6) format.
      result = {}
      vertices.each do |vertex|
        adjacencies = {}
        [:in, :out].each do |direction|
          direction_hash = {}
          adjacencies[direction.to_s] = direction_hash
          adjacent(vertex, :direction => direction, :type => :edges).each do |edge|
            other_vertex = direction == :in ? edge.source : edge.target
            (direction_hash[other_vertex.to_s] ||= []) << edge
          end
          direction_hash.each_pair { |key, edges| direction_hash[key] = edges.uniq.map(&:to_data_hash) }
        end
        vname = vertex.to_s
        result[vname] = { 'adjacencies' => adjacencies, 'vertex' => vname }
      end
      result
    end
    hash
  end

  def multi_vertex_component?(component)
    component.length > 1
  end
  private :multi_vertex_component?

  def single_vertex_referring_to_self?(component)
    if component.length == 1
      vertex = component[0]
      adjacent(vertex).include?(vertex)
    else
      false
    end
  end
  private :single_vertex_referring_to_self?
end
