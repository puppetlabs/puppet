require 'puppet/simple_graph'
require 'puppet/rb_tree_map'

# The relationship graph is the final form of a puppet catalog in
# which all dependency edges are explicitly in the graph. This form of the
# catalog is used to traverse the graph in the order in which resources are
# managed.
#
# @api private
class Puppet::RelationshipGraph < Puppet::SimpleGraph
  attr_reader :blockers

  def initialize
    super

    @priority = {}
    @count = 0

    @ready = Puppet::RbTreeMap.new
    @generated = {}
    @done = {}
    @blockers = {}
    @providerless_types = []
  end

  def add_vertex(vertex, priority = @priority[vertex])
    super(vertex)

    @priority[vertex] = if priority.nil?
                          @count += 1
                        else
                          priority
                        end
  end

  def add_relationship(f, t, label=nil)
    super(f, t, label)
    @ready.delete(resource_priority(t))
  end

  def remove_vertex!(vertex)
    super
    @priority.delete(vertex)
  end

  def resource_priority(resource)
    @priority[resource]
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
      resource.warning "appears to have a negative number of dependencies"
    end
    @blockers[resource] <= 0
  end

  def clear_blockers
    @blockers.clear
  end

  def enqueue(*resources)
    resources.each do |resource|
      key = resource_priority(resource)
      @ready[key] = resource
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
    teardown = options[:teardown] || lambda {}

    report_cycles_in_graph

    enqueue_roots

    deferred_resources = []

    while (resource = next_resource) && continue_while.call()
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
          deferred_resources.each do |resource|
            overly_deferred_resource_handler.call(resource)
            finish(resource)
          end
        end

        made_progress = false
        deferred_resources = []
      end
    end

    teardown.call()
  end
end
