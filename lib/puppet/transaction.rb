require 'puppet'
require 'puppet/util/tagging'
require 'puppet/util/skip_tags'
require 'puppet/application'
require 'digest/sha1'
require 'set'

# the class that actually walks our resource/property tree, collects the changes,
# and performs them
#
# @api private
class Puppet::Transaction
  require 'puppet/transaction/additional_resource_generator'
  require 'puppet/transaction/event'
  require 'puppet/transaction/event_manager'
  require 'puppet/transaction/resource_harness'
  require 'puppet/resource/status'
  require 'puppet/transaction/persistence'

  attr_accessor :catalog, :ignoreschedules, :for_network_device

  # The report, once generated.
  attr_reader :report

  # Routes and stores any events and subscriptions.
  attr_reader :event_manager

  # Handles most of the actual interacting with resources
  attr_reader :resource_harness

  attr_reader :prefetched_providers

  # @!attribute [r] persistence
  #   @return [Puppet::Transaction::Persistence] persistence object for cross
  #      transaction storage.
  attr_reader :persistence

  include Puppet::Util
  include Puppet::Util::Tagging

  def initialize(catalog, report, prioritizer)
    @catalog = catalog

    @persistence = Puppet::Transaction::Persistence.new

    @report = report || Puppet::Transaction::Report.new("apply", catalog.version, catalog.environment)

    @prioritizer = prioritizer

    @report.add_times(:config_retrieval, @catalog.retrieval_duration || 0)

    @event_manager = Puppet::Transaction::EventManager.new(self)

    @resource_harness = Puppet::Transaction::ResourceHarness.new(self)

    @prefetched_providers = Hash.new { |h,k| h[k] = {} }
  end

  # Invoke the pre_run_check hook in every resource in the catalog.
  # This should (only) be called by Transaction#evaluate before applying
  # the catalog.
  #
  # @see Puppet::Transaction#evaluate
  # @see Puppet::Type#pre_run_check
  # @raise [Puppet::Error] If any pre-run checks failed.
  # @return [void]
  def perform_pre_run_checks
    prerun_errors = {}

    @catalog.vertices.each do |res|
      begin
        res.pre_run_check
      rescue Puppet::Error => detail
        prerun_errors[res] = detail
      end
    end

    unless prerun_errors.empty?
      prerun_errors.each do |res, detail|
        res.log_exception(detail)
      end
      raise Puppet::Error, "Some pre-run checks failed"
    end
  end

  # This method does all the actual work of running a transaction.  It
  # collects all of the changes, executes them, and responds to any
  # necessary events.
  def evaluate(&block)
    block ||= method(:eval_resource)
    generator = AdditionalResourceGenerator.new(@catalog, nil, @prioritizer)
    @catalog.vertices.each { |resource| generator.generate_additional_resources(resource) }

    perform_pre_run_checks

    persistence.load if catalog.host_config?

    Puppet.info "Applying configuration version '#{catalog.version}'" if catalog.version

    continue_while = lambda { !stop_processing? }

    post_evalable_providers = Set.new
    pre_process = lambda do |resource|
      prov_class = resource.provider.class
      post_evalable_providers << prov_class if prov_class.respond_to?(:post_resource_eval)

      prefetch_if_necessary(resource)

      # If we generated resources, we don't know what they are now
      # blocking, so we opt to recompute it, rather than try to track every
      # change that would affect the number.
      relationship_graph.clear_blockers if generator.eval_generate(resource)
    end

    providerless_types = []
    overly_deferred_resource_handler = lambda do |resource|
      # We don't automatically assign unsuitable providers, so if there
      # is one, it must have been selected by the user.
      return if missing_tags?(resource)
      if resource.provider
        resource.err "Provider #{resource.provider.class.name} is not functional on this host"
      else
        providerless_types << resource.type
      end

      resource_status(resource).failed = true
    end

    canceled_resource_handler = lambda do |resource|
      resource_status(resource).skipped = true
      resource.debug "Transaction canceled, skipping"
    end

    teardown = lambda do
      # Just once per type. No need to punish the user.
      providerless_types.uniq.each do |type|
        Puppet.err "Could not find a suitable provider for #{type}"
      end

      post_evalable_providers.each do |provider|
        begin
          provider.post_resource_eval
        rescue => detail
          Puppet.log_exception(detail, "post_resource_eval failed for provider #{provider}")
        end
      end

      persistence.save if catalog.host_config?
    end

    # Generate the relationship graph, set up our generator to use it
    # for eval_generate, then kick off our traversal.
    generator.relationship_graph = relationship_graph
    relationship_graph.traverse(:while => continue_while,
                                :pre_process => pre_process,
                                :overly_deferred_resource_handler => overly_deferred_resource_handler,
                                :canceled_resource_handler => canceled_resource_handler,
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
    Puppet::Application.stop_requested? && catalog.host_config?
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
    catalog.relationship_graph(@prioritizer)
  end

  def resource_status(resource)
    report.resource_statuses[resource.to_s] || add_resource_status(Puppet::Resource::Status.new(resource))
  end

  # The tags we should be checking.
  def tags
    self.tags = Puppet[:tags] unless defined?(@tags)

    super
  end

  def skip_tags
    @skip_tags ||= Puppet::Util::SkipTags.new(Puppet[:skip_tags]).tags
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

  # Evaluate a single resource.
  def eval_resource(resource, ancestor = nil)
    propagate_failure(resource)
    if skip?(resource)
      resource_status(resource).skipped = true
      resource.debug("Resource is being skipped, unscheduling all events")
      event_manager.dequeue_all_events_for_resource(resource)
    else
      resource_status(resource).scheduled = true
      apply(resource, ancestor)
      event_manager.process_events(resource)
    end
  end

  def failed?(resource)
    s = resource_status(resource) and s.failed?
  end

  # Does this resource have any failed dependencies?
  def failed_dependencies?(resource)
    # When we introduced the :whit into the graph, to reduce the combinatorial
    # explosion of edges, we also ended up reporting failures for containers
    # like class and stage.  This is undesirable; while just skipping the
    # output isn't perfect, it is RC-safe. --daniel 2011-06-07
    suppress_report = (resource.class == Puppet::Type.type(:whit))

    s = resource_status(resource)
    if s && s.dependency_failed?
      # See above. --daniel 2011-06-06
      unless suppress_report then
        s.failed_dependencies.each do |dep|
          resource.notice "Dependency #{dep} has failures: #{resource_status(dep).failed}"
        end
      end
    end

    s && s.dependency_failed?
  end

  # We need to know if a resource has any failed dependencies before
  # we try to process it. We keep track of this by keeping a list on
  # each resource of the failed dependencies, and incrementally
  # computing it as the union of the failed dependencies of each
  # first-order dependency. We have to do this as-we-go instead of
  # up-front at failure time because the graph may be mutated as we
  # walk it.
  def propagate_failure(resource)
    failed = Set.new
    relationship_graph.direct_dependencies_of(resource).each do |dep|
      if (s = resource_status(dep))
        failed.merge(s.failed_dependencies) if s.dependency_failed?
        if s.failed?
          failed.add(dep)
        end
      end
    end
    resource_status(resource).failed_dependencies = failed.to_a
  end

  # Should we ignore tags?
  def ignore_tags?
    ! @catalog.host_config?
  end

  def resources_by_provider(type_name, provider_name)
    unless @resources_by_provider
      @resources_by_provider = Hash.new { |h, k| h[k] = Hash.new { |h1, k1| h1[k1] = {} } }

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
    rescue LoadError, Puppet::MissingCommand => detail
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
    if skip_tags?(resource)
      resource.debug "Skipping with skip tags #{skip_tags.join(", ")}"
    elsif missing_tags?(resource)
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

  # Is this resource tagged appropriately?
  def missing_tags?(resource)
    return false if ignore_tags?
    return false if tags.empty?

    not resource.tagged?(*tags)
  end

  def skip_tags?(resource)
    return false if ignore_tags?
    return false if skip_tags.empty?

    resource.tagged?(*skip_tags)
  end

  def split_qualified_tags?
    false
  end

  # These two methods are only made public to enable the existing spec tests to run
  # under rspec 3 (apparently rspec 2 didn't enforce access controls?). Please do not
  # treat these as part of a public API.
  # Possible future improvement: rewrite to not require access to private methods.
  public :skip?
  public :missing_tags?

end

require 'puppet/transaction/report'
