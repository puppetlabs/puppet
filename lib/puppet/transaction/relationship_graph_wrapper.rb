require 'puppet/rb_tree_map'

# We want to monitor changes in the relationship graph of our
# catalog but this is complicated by the fact that the catalog
# both is_a graph and has_a graph, by the fact that changes to
# the structure of the object can have adverse serialization
# effects, by threading issues, by order-of-initialization issues,
# etc.
#
# Since the proper lifetime/scope of the monitoring is a transaction
# and the transaction is already commiting a mild law-of-demeter
# transgression, we cut the Gordian knot here by simply wrapping the
# transaction's view of the resource graph to capture and maintain
# the information we need.  Nothing outside the transaction needs
# this information, and nothing outside the transaction can see it
# except via the Transaction#relationship_graph
class Puppet::Transaction::RelationshipGraphWrapper
  attr_reader :blockers, :ready, :done, :unguessable_deterministic_key

  def initialize(real_graph, transaction)
    @real_graph = real_graph
    @transaction = transaction
    @ready = Puppet::RbTreeMap.new
    @generated = {}
    @done = {}
    @blockers = {}
    @unguessable_deterministic_key = Hash.new { |h,k| h[k] = Digest::SHA1.hexdigest("NaCl, MgSO4 (salts) and then #{k.ref}") }
    @providerless_types = []
  end

  def method_missing(*args, &block)
    @real_graph.send(*args, &block)
  end

  def add_vertex(v)
    @real_graph.add_vertex(v)
  end

  def add_edge(f, t, label=nil)
    key = @unguessable_deterministic_key[t]

    @ready.delete(key)

    @real_graph.add_edge(f, t, label)
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

  def enqueue(*resources)
    resources.each do |resource|
      key = @unguessable_deterministic_key[resource]
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

  def traverse(&block)
    @real_graph.report_cycles_in_graph

    enqueue_roots

    deferred_resources = []

    while (resource = next_resource) && !@transaction.stop_processing?
      if resource.suitable?
        made_progress = true

        @transaction.prefetch_if_necessary(resource)

        # If we generated resources, we don't know what they are now
        # blocking, so we opt to recompute it, rather than try to track every
        # change that would affect the number.
        @blockers.clear if @transaction.eval_generate(resource)

        yield resource

        finish(resource)
      else
        deferred_resources << resource
      end

      if @ready.empty? and deferred_resources.any?
        if made_progress
          enqueue(*deferred_resources)
        else
          fail_unsuitable_resources(deferred_resources)
        end

        made_progress = false
        deferred_resources = []
      end
    end

    # Just once per type. No need to punish the user.
    @providerless_types.uniq.each do |type|
      Puppet.err "Could not find a suitable provider for #{type}"
    end
  end

  def fail_unsuitable_resources(resources)
    resources.each do |resource|
      # We don't automatically assign unsuitable providers, so if there
      # is one, it must have been selected by the user.
      if resource.provider
        resource.err "Provider #{resource.provider.class.name} is not functional on this host"
      else
        @providerless_types << resource.type
      end

      @transaction.resource_status(resource).failed = true

      finish(resource)
    end
  end
end
