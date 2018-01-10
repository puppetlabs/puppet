# The relationship graph is the final form of a puppet catalog in
# which all dependency edges are explicitly in the graph. This form of the
# catalog is used to traverse the graph in the order in which resources are
# managed.
#
# @api private
class Puppet::Graph::RelationshipGraph < Puppet::Graph::SimpleGraph
  attr_reader :blockers

  def initialize(prioritizer)
    super()

    @prioritizer = prioritizer

    @ready = Puppet::Graph::RbTreeMap.new
    @generated = {}
    @done = {}
    @blockers = {}
    @providerless_types = []
  end

  def populate_from(catalog)
    add_all_resources_as_vertices(catalog)
    build_manual_dependencies
    build_autorelation_dependencies(catalog)

    write_graph(:relationships) if catalog.host_config?

    replace_containers_with_anchors(catalog)

    write_graph(:expanded_relationships) if catalog.host_config?
  end

  def add_vertex(vertex, priority = nil)
    super(vertex)

    if priority
      @prioritizer.record_priority_for(vertex, priority)
    else
      @prioritizer.generate_priority_for(vertex)
    end
  end

  def add_relationship(f, t, label=nil)
    super(f, t, label)
    @ready.delete(@prioritizer.priority_of(t))
  end

  def remove_vertex!(vertex)
    super
    @prioritizer.forget(vertex)
  end

  def resource_priority(resource)
    @prioritizer.priority_of(resource)
  end

  # Enqueue the initial set of resources, those with no dependencies.
  def enqueue_roots
    vertices.each do |v|
      @blockers[v] = direct_dependencies_of(v).length
      enqueue(v) if @blockers[v] == 0
    end
  end

  # Decrement the blocker count for the resource by 1. If the number of
  # blockers is unknown, count them and THEN decrement by 1.
  def unblock(resource)
    @blockers[resource] ||= direct_dependencies_of(resource).select { |r2| !@done[r2] }.length
    if @blockers[resource] > 0
      @blockers[resource] -= 1
    else
      resource.warning _("appears to have a negative number of dependencies")
    end
    @blockers[resource] <= 0
  end

  def clear_blockers
    @blockers.clear
  end

  def enqueue(*resources)
    resources.each do |resource|
      @ready[@prioritizer.priority_of(resource)] = resource
    end
  end

  def finish(resource)
    direct_dependents_of(resource).each do |v|
      enqueue(v) if unblock(v)
    end
    @done[resource] = true
  end

  def next_resource
    @ready.delete_min
  end

  def traverse(options = {}, &block)
    continue_while = options[:while] || lambda { true }
    pre_process = options[:pre_process] || lambda { |resource| }
    overly_deferred_resource_handler = options[:overly_deferred_resource_handler] || lambda { |resource| }
    canceled_resource_handler = options[:canceled_resource_handler] || lambda { |resource| }
    teardown = options[:teardown] || lambda {}
    graph_cycle_handler = options[:graph_cycle_handler] || lambda { [] }

    if cycles = report_cycles_in_graph
      graph_cycle_handler.call(cycles)
    end

    enqueue_roots

    deferred_resources = []

    while continue_while.call() && (resource = next_resource)
      if resource.suitable?
        made_progress = true

        pre_process.call(resource)

        yield resource

        finish(resource)
      else
        deferred_resources << resource
      end

      if @ready.empty? and deferred_resources.any?
        if made_progress
          enqueue(*deferred_resources)
        else
          deferred_resources.each do |res|
            overly_deferred_resource_handler.call(res)
            finish(res)
          end
        end

        made_progress = false
        deferred_resources = []
      end
    end

    if !continue_while.call()
      while (resource = next_resource)
        canceled_resource_handler.call(resource)
        finish(resource)
      end
    end

    teardown.call()
  end

  private

  def add_all_resources_as_vertices(catalog)
    catalog.resources.each do |vertex|
      add_vertex(vertex)
    end
  end

  def build_manual_dependencies
    vertices.each do |vertex|
      vertex.builddepends.each do |edge|
        add_edge(edge)
      end
    end
  end

  def build_autorelation_dependencies(catalog)
    vertices.each do |vertex|
      [:require,:subscribe].each do |rel_type|
        vertex.send("auto#{rel_type}".to_sym, catalog).each do |edge|
          # don't let automatic relationships conflict with manual ones.
          next if edge?(edge.source, edge.target)

          if edge?(edge.target, edge.source)
            vertex.debug "Skipping automatic relationship with #{edge.source}"
          else
            vertex.debug "Adding auto#{rel_type} relationship with #{edge.source}"
            if rel_type == :require
              edge.event = :NONE
            else
              edge.callback = :refresh
              edge.event = :ALL_EVENTS
            end
            add_edge(edge)
          end
        end
      end

      [:before,:notify].each do |rel_type|
        vertex.send("auto#{rel_type}".to_sym, catalog).each do |edge|
          # don't let automatic relationships conflict with manual ones.
          next if edge?(edge.target, edge.source)

          if edge?(edge.source, edge.target)
            vertex.debug "Skipping automatic relationship with #{edge.target}"
          else
            vertex.debug "Adding auto#{rel_type} relationship with #{edge.target}"
            if rel_type == :before
              edge.event = :NONE
            else
              edge.callback = :refresh
              edge.event = :ALL_EVENTS
            end
            add_edge(edge)
          end
        end
      end
    end
  end

  # Impose our container information on another graph by using it
  # to replace any container vertices X with a pair of vertices
  # { admissible_X and completed_X } such that
  #
  #    0) completed_X depends on admissible_X
  #    1) contents of X each depend on admissible_X
  #    2) completed_X depends on each on the contents of X
  #    3) everything which depended on X depends on completed_X
  #    4) admissible_X depends on everything X depended on
  #    5) the containers and their edges must be removed
  #
  # Note that this requires attention to the possible case of containers
  # which contain or depend on other containers, but has the advantage
  # that the number of new edges created scales linearly with the number
  # of contained vertices regardless of how containers are related;
  # alternatives such as replacing container-edges with content-edges
  # scale as the product of the number of external dependencies, which is
  # to say geometrically in the case of nested / chained containers.
  #
  Default_label = { :callback => :refresh, :event => :ALL_EVENTS }
  def replace_containers_with_anchors(catalog)
    stage_class      = Puppet::Type.type(:stage)
    whit_class       = Puppet::Type.type(:whit)
    component_class  = Puppet::Type.type(:component)
    containers = catalog.resources.find_all { |v| (v.is_a?(component_class) or v.is_a?(stage_class)) and vertex?(v) }
    #
    # These two hashes comprise the aforementioned attention to the possible
    #   case of containers that contain / depend on other containers; they map
    #   containers to their sentinels but pass other vertices through.  Thus we
    #   can "do the right thing" for references to other vertices that may or
    #   may not be containers.
    #
    admissible = Hash.new { |h,k| k }
    completed  = Hash.new { |h,k| k }
    containers.each { |x|
      admissible[x] = whit_class.new(:name => "admissible_#{x.ref}", :catalog => catalog)
      completed[x]  = whit_class.new(:name => "completed_#{x.ref}",  :catalog => catalog)

      # This copies the original container's tags over to the two anchor whits.
      # Without this, tags are not propagated to the container's resources.
      admissible[x].set_tags(x)
      completed[x].set_tags(x)

      priority = @prioritizer.priority_of(x)
      add_vertex(admissible[x], priority)
      add_vertex(completed[x], priority)
    }
    #
    # Implement the six requirements listed above
    #
    containers.each { |x|
      contents = catalog.adjacent(x, :direction => :out)
      add_edge(admissible[x],completed[x]) if contents.empty? # (0)
      contents.each { |v|
        add_edge(admissible[x],admissible[v],Default_label) # (1)
        add_edge(completed[v], completed[x], Default_label) # (2)
      }
      # (3) & (5)
      adjacent(x,:direction => :in,:type => :edges).each { |e|
        add_edge(completed[e.source],admissible[x],e.label)
        remove_edge! e
      }
      # (4) & (5)
      adjacent(x,:direction => :out,:type => :edges).each { |e|
        add_edge(completed[x],admissible[e.target],e.label)
        remove_edge! e
      }
    }
    containers.each { |x| remove_vertex! x } # (5)
  end
end
