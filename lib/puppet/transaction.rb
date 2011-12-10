# the class that actually walks our resource/property tree, collects the changes,
# and performs them

require 'puppet'
require 'puppet/util/tagging'
require 'puppet/application'
require 'digest/sha1'

class Puppet::Transaction
  require 'puppet/transaction/event'
  require 'puppet/transaction/event_manager'
  require 'puppet/transaction/resource_harness'
  require 'puppet/resource/status'

  attr_accessor :component, :catalog, :ignoreschedules, :for_network_device
  attr_accessor :configurator

  # The report, once generated.
  attr_reader :report

  # Routes and stores any events and subscriptions.
  attr_reader :event_manager

  # Handles most of the actual interacting with resources
  attr_reader :resource_harness

  include Puppet::Util
  include Puppet::Util::Tagging

  # Wraps application run state check to flag need to interrupt processing
  def stop_processing?
    Puppet::Application.stop_requested?
  end

  # Add some additional times for reporting
  def add_times(hash)
    hash.each do |name, num|
      report.add_times(name, num)
    end
  end

  # Are there any failed resources in this transaction?
  def any_failed?
    report.resource_statuses.values.detect { |status| status.failed? }
  end

  # Apply all changes for a resource
  def apply(resource, ancestor = nil)
    status = resource_harness.evaluate(resource)
    add_resource_status(status)
    event_manager.queue_events(ancestor || resource, status.events) unless status.failed?
  rescue => detail
    resource.err "Could not evaluate: #{detail}"
  end

  # Find all of the changed resources.
  def changed?
    report.resource_statuses.values.find_all { |status| status.changed }.collect { |status| catalog.resource(status.resource) }
  end

  # Find all of the applied resources (including failed attempts).
  def applied_resources
    report.resource_statuses.values.collect { |status| catalog.resource(status.resource) }
  end

  # Copy an important relationships from the parent to the newly-generated
  # child resource.
  def add_conditional_directed_dependency(parent, child, label=nil)
    relationship_graph.add_vertex(child)
    edge = parent.depthfirst? ? [child, parent] : [parent, child]
    if relationship_graph.edge?(*edge.reverse)
      parent.debug "Skipping automatic relationship to #{child}"
    else
      relationship_graph.add_edge(edge[0],edge[1],label)
    end
  end

  # Evaluate a single resource.
  def eval_resource(resource, ancestor = nil)
    if skip?(resource)
      resource_status(resource).skipped = true
    else
      resource_status(resource).scheduled = true
      apply(resource, ancestor)
    end

    # Check to see if there are any events queued for this resource
    event_manager.process_events(resource)
  end

  # This method does all the actual work of running a transaction.  It
  # collects all of the changes, executes them, and responds to any
  # necessary events.
  def evaluate
    add_dynamically_generated_resources

    Puppet.info "Applying configuration version '#{catalog.version}'" if catalog.version

    relationship_graph.traverse do |resource|
      if resource.is_a?(Puppet::Type::Component)
        Puppet.warning "Somehow left a component in the relationship graph"
      else
        seconds = thinmark { eval_resource(resource) }
        resource.info "Evaluated in %0.2f seconds" % seconds if Puppet[:evaltrace] and @catalog.host_config?
      end
    end

    Puppet.debug "Finishing transaction #{object_id}"
  end

  def events
    event_manager.events
  end

  def failed?(resource)
    s = resource_status(resource) and s.failed?
  end

  # Does this resource have any failed dependencies?
  def failed_dependencies?(resource)
    # First make sure there are no failed dependencies.  To do this,
    # we check for failures in any of the vertexes above us.  It's not
    # enough to check the immediate dependencies, which is why we use
    # a tree from the reversed graph.
    found_failed = false


    # When we introduced the :whit into the graph, to reduce the combinatorial
    # explosion of edges, we also ended up reporting failures for containers
    # like class and stage.  This is undesirable; while just skipping the
    # output isn't perfect, it is RC-safe. --daniel 2011-06-07
    suppress_report = (resource.class == Puppet::Type.type(:whit))

    relationship_graph.dependencies(resource).each do |dep|
      next unless failed?(dep)
      found_failed = true

      # See above. --daniel 2011-06-06
      unless suppress_report then
        resource.notice "Dependency #{dep} has failures: #{resource_status(dep).failed}"
      end
    end

    found_failed
  end

  def eval_generate(resource)
    return false unless resource.respond_to?(:eval_generate)
    raise Puppet::DevError,"Depthfirst resources are not supported by eval_generate" if resource.depthfirst?
    begin
      made = resource.eval_generate.uniq
      return false if made.empty?
      made = made.inject({}) {|a,v| a.merge(v.name => v) }
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      resource.err "Failed to generate additional resources using 'eval_generate: #{detail}"
      return false
    end
    made.values.each do |res|
      begin
        res.tag(*resource.tags)
        @catalog.add_resource(res)
        res.finish
      rescue Puppet::Resource::Catalog::DuplicateResourceError
        res.info "Duplicate generated resource; skipping"
      end
    end
    sentinel = Puppet::Type.type(:whit).new(:name => "completed_#{resource.title}", :catalog => resource.catalog)

    # The completed whit is now the thing that represents the resource is done
    relationship_graph.adjacent(resource,:direction => :out,:type => :edges).each { |e|
      # But children run as part of the resource, not after it
      next if made[e.target.name]

      add_conditional_directed_dependency(sentinel, e.target, e.label)
      relationship_graph.remove_edge! e
    }

    default_label = Puppet::Resource::Catalog::Default_label
    made.values.each do |res|
      # Depend on the nearest ancestor we generated, falling back to the
      # resource if we have none
      parent_name = res.ancestors.find { |a| made[a] and made[a] != res }
      parent = made[parent_name] || resource

      add_conditional_directed_dependency(parent, res)

      # This resource isn't 'completed' until each child has run
      add_conditional_directed_dependency(res, sentinel, default_label)
    end

    # This edge allows the resource's events to propagate, though it isn't
    # strictly necessary for ordering purposes
    add_conditional_directed_dependency(resource, sentinel, default_label)
    true
  end

  # A general method for recursively generating new resources from a
  # resource.
  def generate_additional_resources(resource)
    return unless resource.respond_to?(:generate)
    begin
      made = resource.generate
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      resource.err "Failed to generate additional resources using 'generate': #{detail}"
    end
    return unless made
    made = [made] unless made.is_a?(Array)
    made.uniq.each do |res|
      begin
        res.tag(*resource.tags)
        @catalog.add_resource(res)
        res.finish
        add_conditional_directed_dependency(resource, res)
        generate_additional_resources(res)
      rescue Puppet::Resource::Catalog::DuplicateResourceError
        res.info "Duplicate generated resource; skipping"
      end
    end
  end

  def add_dynamically_generated_resources
    @catalog.vertices.each { |resource| generate_additional_resources(resource) }
  end

  # Should we ignore tags?
  def ignore_tags?
    ! (@catalog.host_config? or Puppet[:name] == "puppet")
  end

  # this should only be called by a Puppet::Type::Component resource now
  # and it should only receive an array
  def initialize(catalog, report = nil)
    @catalog = catalog

    @report = report || Puppet::Transaction::Report.new("apply", catalog.version)

    @event_manager = Puppet::Transaction::EventManager.new(self)

    @resource_harness = Puppet::Transaction::ResourceHarness.new(self)

    @prefetched_providers = Hash.new { |h,k| h[k] = {} }
  end

  def resources_by_provider(type_name, provider_name)
    unless @resources_by_provider
      @resources_by_provider = Hash.new { |h, k| h[k] = Hash.new { |h, k| h[k] = {} } }

      @catalog.vertices.each do |resource|
        if resource.class.attrclass(:provider)
          prov = resource.provider && resource.provider.class.name
          @resources_by_provider[resource.type][prov][resource.name] = resource
        end
      end
    end

    @resources_by_provider[type_name][provider_name] || {}
  end

  def prefetch_if_necessary(resource)
    provider_class = resource.provider.class
    return unless provider_class.respond_to?(:prefetch) and !prefetched_providers[resource.type][provider_class.name]

    resources = resources_by_provider(resource.type, provider_class.name)

    if provider_class == resource.class.defaultprovider
      providerless_resources = resources_by_provider(resource.type, nil)
      providerless_resources.values.each {|res| res.provider = provider_class.name}
      resources.merge! providerless_resources
    end

    prefetch(provider_class, resources)
  end

  attr_reader :prefetched_providers

  # Prefetch any providers that support it, yo.  We don't support prefetching
  # types, just providers.
  def prefetch(provider_class, resources)
    type_name = provider_class.resource_type.name
    return if @prefetched_providers[type_name][provider_class.name]
    Puppet.debug "Prefetching #{provider_class.name} resources for #{type_name}"
    begin
      provider_class.prefetch(resources)
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      Puppet.err "Could not prefetch #{type_name} provider '#{provider_class.name}': #{detail}"
    end
    @prefetched_providers[type_name][provider_class.name] = true
  end

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

  class Relationship_graph_wrapper
    require 'puppet/rb_tree_map'
    attr_reader :real_graph,:transaction,:ready,:generated,:done,:blockers,:unguessable_deterministic_key
    def initialize(real_graph,transaction)
      @real_graph = real_graph
      @transaction = transaction
      @ready = Puppet::RbTreeMap.new
      @generated = {}
      @done = {}
      @blockers = {}
      @unguessable_deterministic_key = Hash.new { |h,k| h[k] = Digest::SHA1.hexdigest("NaCl, MgSO4 (salts) and then #{k.ref}") }
      @providerless_types = []
      vertices.each do |v|
        blockers[v] = direct_dependencies_of(v).length
        enqueue(v) if blockers[v] == 0
      end
    end
    def method_missing(*args,&block)
      real_graph.send(*args,&block)
    end
    def add_vertex(v)
      real_graph.add_vertex(v)
    end
    def add_edge(f,t,label=nil)
      key = unguessable_deterministic_key[t]

      ready.delete(key)

      real_graph.add_edge(f,t,label)
    end
    # Decrement the blocker count for the resource by 1. If the number of
    # blockers is unknown, count them and THEN decrement by 1.
    def unblock(resource)
      blockers[resource] ||= direct_dependencies_of(resource).select { |r2| !done[r2] }.length
      if blockers[resource] > 0
        blockers[resource] -= 1
      else
        resource.warning "appears to have a negative number of dependencies"
      end
      blockers[resource] <= 0
    end
    def enqueue(*resources)
      resources.each do |resource|
        key = unguessable_deterministic_key[resource]
        ready[key] = resource
      end
    end
    def finish(resource)
      direct_dependents_of(resource).each do |v|
        enqueue(v) if unblock(v)
      end
      done[resource] = true
    end
    def next_resource
      ready.delete_min
    end
    def traverse(&block)
      real_graph.report_cycles_in_graph

      deferred_resources = []

      while (resource = next_resource) && !transaction.stop_processing?
        if resource.suitable?
          made_progress = true

          transaction.prefetch_if_necessary(resource)

          # If we generated resources, we don't know what they are now
          # blocking, so we opt to recompute it, rather than try to track every
          # change that would affect the number.
          blockers.clear if transaction.eval_generate(resource)

          yield resource

          finish(resource)
        else
          deferred_resources << resource
        end

        if ready.empty? and deferred_resources.any?
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

        transaction.resource_status(resource).failed = true

        finish(resource)
      end
    end
  end

  def relationship_graph
    @relationship_graph ||= Relationship_graph_wrapper.new(catalog.relationship_graph,self)
  end

  def add_resource_status(status)
    report.add_resource_status status
  end

  def resource_status(resource)
    report.resource_statuses[resource.to_s] || add_resource_status(Puppet::Resource::Status.new(resource))
  end

  # Is the resource currently scheduled?
  def scheduled?(resource)
    self.ignoreschedules or resource_harness.scheduled?(resource_status(resource), resource)
  end

  # Should this resource be skipped?
  def skip?(resource)
    if missing_tags?(resource)
      resource.debug "Not tagged with #{tags.join(", ")}"
    elsif ! scheduled?(resource)
      resource.debug "Not scheduled"
    elsif failed_dependencies?(resource)
      # When we introduced the :whit into the graph, to reduce the combinatorial
      # explosion of edges, we also ended up reporting failures for containers
      # like class and stage.  This is undesirable; while just skipping the
      # output isn't perfect, it is RC-safe. --daniel 2011-06-07
      unless resource.class == Puppet::Type.type(:whit) then
        resource.warning "Skipping because of failed dependencies"
      end
    elsif resource.virtual?
      resource.debug "Skipping because virtual"
    elsif resource.appliable_to_device? ^ for_network_device
      resource.debug "Skipping #{resource.appliable_to_device? ? 'device' : 'host'} resources because running on a #{for_network_device ? 'device' : 'host'}"
    else
      return false
    end
    true
  end

  # The tags we should be checking.
  def tags
    self.tags = Puppet[:tags] unless defined?(@tags)

    super
  end

  def handle_qualified_tags( qualified )
    # The default behavior of Puppet::Util::Tagging is
    # to split qualified tags into parts. That would cause
    # qualified tags to match too broadly here.
    return
  end

  # Is this resource tagged appropriately?
  def missing_tags?(resource)
    return false if ignore_tags?
    return false if tags.empty?

    not resource.tagged?(*tags)
  end
end

require 'puppet/transaction/report'

