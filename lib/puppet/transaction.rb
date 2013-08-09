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

  attr_accessor :catalog, :ignoreschedules, :for_network_device

  # The report, once generated.
  attr_reader :report

  # Routes and stores any events and subscriptions.
  attr_reader :event_manager

  # Handles most of the actual interacting with resources
  attr_reader :resource_harness

  attr_reader :prefetched_providers

  include Puppet::Util
  include Puppet::Util::Tagging

  def initialize(catalog, report = nil)
    @catalog = catalog

    @report = report || Puppet::Transaction::Report.new("apply", catalog.version, catalog.environment)

    @report.add_times(:config_retrieval, @catalog.retrieval_duration || 0)

    @event_manager = Puppet::Transaction::EventManager.new(self)

    @resource_harness = Puppet::Transaction::ResourceHarness.new(self)

    @prefetched_providers = Hash.new { |h,k| h[k] = {} }
  end

  # This method does all the actual work of running a transaction.  It
  # collects all of the changes, executes them, and responds to any
  # necessary events.
  def evaluate(&block)
    block ||= method(:eval_resource)
    add_dynamically_generated_resources

    Puppet.info "Applying configuration version '#{catalog.version}'" if catalog.version

    continue_while = lambda { !stop_processing? }

    pre_process = lambda do |resource|
      prefetch_if_necessary(resource)

      # If we generated resources, we don't know what they are now
      # blocking, so we opt to recompute it, rather than try to track every
      # change that would affect the number.
      relationship_graph.clear_blockers if eval_generate(resource)
    end

    providerless_types = []
    overly_deferred_resource_handler = lambda do |resource|
      # We don't automatically assign unsuitable providers, so if there
      # is one, it must have been selected by the user.
      if resource.provider
        resource.err "Provider #{resource.provider.class.name} is not functional on this host"
      else
        providerless_types << resource.type
      end

      resource_status(resource).failed = true
    end

    teardown = lambda do
      # Just once per type. No need to punish the user.
      providerless_types.uniq.each do |type|
        Puppet.err "Could not find a suitable provider for #{type}"
      end
    end

    relationship_graph.traverse(:while => continue_while,
                                :pre_process => pre_process,
                                :overly_deferred_resource_handler => overly_deferred_resource_handler,
                                :teardown => teardown) do |resource|
      if resource.is_a?(Puppet::Type::Component)
        Puppet.warning "Somehow left a component in the relationship graph"
      else
        resource.info "Starting to evaluate the resource" if Puppet[:evaltrace] and @catalog.host_config?
        seconds = thinmark { block.call(resource) }
        resource.info "Evaluated in %0.2f seconds" % seconds if Puppet[:evaltrace] and @catalog.host_config?
      end
    end

    Puppet.debug "Finishing transaction #{object_id}"
  end

  # Wraps application run state check to flag need to interrupt processing
  def stop_processing?
    Puppet::Application.stop_requested?
  end

  # Are there any failed resources in this transaction?
  def any_failed?
    report.resource_statuses.values.detect { |status| status.failed? }
  end

  # Find all of the changed resources.
  def changed?
    report.resource_statuses.values.find_all { |status| status.changed }.collect { |status| catalog.resource(status.resource) }
  end

  def relationship_graph
    @relationship_graph ||= catalog.relationship_graph
  end

  def resource_status(resource)
    report.resource_statuses[resource.to_s] || add_resource_status(Puppet::Resource::Status.new(resource))
  end

  # The tags we should be checking.
  def tags
    self.tags = Puppet[:tags] unless defined?(@tags)

    super
  end

  def eval_generate(resource)
    return false unless resource.respond_to?(:eval_generate)
    raise Puppet::DevError,"Depthfirst resources are not supported by eval_generate" if resource.depthfirst?
    begin
      made = resource.eval_generate.uniq
      return false if made.empty?
      made = Hash[made.map(&:name).zip(made)]
    rescue => detail
      resource.log_exception(detail, "Failed to generate additional resources using 'eval_generate: #{detail}")
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

    default_label = Puppet::RelationshipGraph::Default_label
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

  private

  # Apply all changes for a resource
  def apply(resource, ancestor = nil)
    status = resource_harness.evaluate(resource)
    add_resource_status(status)
    event_manager.queue_events(ancestor || resource, status.events) unless status.failed?
  rescue => detail
    resource.err "Could not evaluate: #{detail}"
  end

  # Copy an important relationships from the parent to the newly-generated
  # child resource.
  def add_conditional_directed_dependency(parent, child, label=nil)
    relationship_graph.add_vertex(child)
    edge = parent.depthfirst? ? [child, parent] : [parent, child]
    if relationship_graph.edge?(*edge.reverse)
      parent.debug "Skipping automatic relationship to #{child}"
    else
      relationship_graph.add_relationship(edge[0],edge[1],label)
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

  def add_dynamically_generated_resources
    @catalog.vertices.each { |resource| generate_additional_resources(resource) }
  end

  # A general method for recursively generating new resources from a
  # resource.
  def generate_additional_resources(resource)
    return unless resource.respond_to?(:generate)
    begin
      made = resource.generate
    rescue => detail
      resource.log_exception(detail, "Failed to generate additional resources using 'generate': #{detail}")
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

  # Should we ignore tags?
  def ignore_tags?
    ! @catalog.host_config?
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

  # Prefetch any providers that support it, yo.  We don't support prefetching
  # types, just providers.
  def prefetch(provider_class, resources)
    type_name = provider_class.resource_type.name
    return if @prefetched_providers[type_name][provider_class.name]
    Puppet.debug "Prefetching #{provider_class.name} resources for #{type_name}"
    begin
      provider_class.prefetch(resources)
    rescue => detail
      Puppet.log_exception(detail, "Could not prefetch #{type_name} provider '#{provider_class.name}': #{detail}")
    end
    @prefetched_providers[type_name][provider_class.name] = true
  end

  def add_resource_status(status)
    report.add_resource_status(status)
  end

  # Is the resource currently scheduled?
  def scheduled?(resource)
    self.ignoreschedules or resource_harness.scheduled?(resource)
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
    elsif !host_and_device_resource?(resource) && resource.appliable_to_host? && for_network_device
      resource.debug "Skipping host resources because running on a device"
    elsif !host_and_device_resource?(resource) && resource.appliable_to_device? && !for_network_device
      resource.debug "Skipping device resources because running on a posix host"
    else
      return false
    end
    true
  end

  def host_and_device_resource?(resource)
    resource.appliable_to_host? && resource.appliable_to_device?
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

