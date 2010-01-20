# the class that actually walks our resource/property tree, collects the changes,
# and performs them

require 'puppet'
require 'puppet/util/tagging'

class Puppet::Transaction
    require 'puppet/transaction/change'
    require 'puppet/transaction/event'
    require 'puppet/transaction/event_manager'
    require 'puppet/transaction/resource_harness'
    require 'puppet/resource/status'

    attr_accessor :component, :catalog, :ignoreschedules
    attr_accessor :sorted_resources, :configurator

    # The report, once generated.
    attr_reader :report

    # Mostly only used for tests
    attr_reader :resourcemetrics, :changes

    # Routes and stores any events and subscriptions.
    attr_reader :event_manager

    # Handles most of the actual interacting with resources
    attr_reader :resource_harness

    include Puppet::Util
    include Puppet::Util::Tagging

    # Add some additional times for reporting
    def addtimes(hash)
        hash.each do |name, num|
            @timemetrics[name] = num
        end
    end

    # Check to see if we should actually allow processing, but this really only
    # matters when a resource is getting deleted.
    def allow_processing?(resource, changes)
        # If a resource is going to be deleted but it still has
        # dependencies, then don't delete it unless it's implicit or the
        # dependency is itself being deleted.
        if resource.purging? and resource.deleting?
            if deps = relationship_graph.dependents(resource) and ! deps.empty? and deps.detect { |d| ! d.deleting? }
                resource.warning "%s still depend%s on me -- not purging" %
                    [deps.collect { |r| r.ref }.join(","), deps.length > 1 ? "":"s"]
                return false
            end
        end

        return true
    end

    # Are there any failed resources in this transaction?
    def any_failed?
        failures = @failures.inject(0) { |failures, array| failures += array[1]; failures }
        if failures > 0
            failures
        else
            false
        end
    end

    # Apply all changes for a resource
    def apply(resource)
        status = resource_harness.evaluate(resource)
        add_resource_status(status)
        status.events.each do |event|
            event_manager.queue_event(resource, event)
        end
    rescue => detail
        resource.err "Could not evaluate: #{detail}"
    end

    # Apply each change in turn.
    def apply_changes(resource, changes)
        changes.each { |change| apply_change(resource, change) }
    end

    # Find all of the changed resources.
    def changed?
        @changes.find_all { |change| change.changed }.collect do |change|
            unless change.property.resource
                raise "No resource for %s" % change.inspect
            end
            change.property.resource
        end.uniq
    end

    # Do any necessary cleanup.  If we don't get rid of the graphs, the
    # contained resources might never get cleaned up.
    def cleanup
        if defined? @generated
            catalog.remove_resource(*@generated)
        end
    end

    # Copy an important relationships from the parent to the newly-generated
    # child resource.
    def make_parent_child_relationship(resource, children)
        depthfirst = resource.depthfirst?

        children.each do |gen_child|
            if depthfirst
                edge = [gen_child, resource]
            else
                edge = [resource, gen_child]
            end
            relationship_graph.add_vertex(gen_child)

            unless relationship_graph.edge?(edge[1], edge[0])
                relationship_graph.add_edge(*edge)
            else
                resource.debug "Skipping automatic relationship to %s" % gen_child
            end
        end
    end

    # See if the resource generates new resources at evaluation time.
    def eval_generate(resource)
        generate_additional_resources(resource, :eval_generate)
    end

    # Evaluate a single resource.
    def eval_resource(resource)
        if skip?(resource)
            @resourcemetrics[:skipped] += 1
            return
        end

        eval_children_and_apply_resource(resource)

        # Check to see if there are any events queued for this resource
        event_manager.process_events(resource)
    end

    def eval_children_and_apply_resource(resource)
        @resourcemetrics[:scheduled] += 1

        changecount = @changes.length

        # We need to generate first regardless, because the recursive
        # actions sometimes change how the top resource is applied.
        children = eval_generate(resource)

        if ! children.empty? and resource.depthfirst?
            children.each do |child|
                # The child will never be skipped when the parent isn't
                eval_resource(child, false)
            end
        end

        # Perform the actual changes
        seconds = thinmark do
            apply(resource)
        end

        if ! children.empty? and ! resource.depthfirst?
            children.each do |child|
                eval_resource(child)
            end
        end

        unless children.empty?
            @changes[changecount..-1].each { |change| change.proxy = resource }
        end

        # Keep track of how long we spend in each type of resource
        @timemetrics[resource.class.name] += seconds
    end

    # This method does all the actual work of running a transaction.  It
    # collects all of the changes, executes them, and responds to any
    # necessary events.
    def evaluate
        # Start logging.
        Puppet::Util::Log.newdestination(@report)

        prepare()

        Puppet.info "Applying configuration version '%s'" % catalog.version if catalog.version

        begin
            @sorted_resources.each do |resource|
                if resource.is_a?(Puppet::Type::Component)
                    Puppet.warning "Somehow left a component in the relationship graph"
                    next
                end
                ret = nil
                seconds = thinmark do
                    ret = eval_resource(resource)
                end

                if Puppet[:evaltrace] and @catalog.host_config?
                    resource.info "Evaluated in %0.2f seconds" % seconds
                end
                ret
            end
        ensure
            # And then close the transaction log.
            Puppet::Util::Log.close(@report)
        end

        Puppet.debug "Finishing transaction #{object_id} with #{@changes.length} changes"
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
        relationship_graph.dependencies(resource).each do |dep|
            next unless failed?(dep)
            resource.notice "Dependency #{dep} has failures: #{resource_status(dep).failed}"
            found_failed = true
        end

        return found_failed
    end

    # A general method for recursively generating new resources from a
    # resource.
    def generate_additional_resources(resource, method)
        return [] unless resource.respond_to?(method)
        begin
            made = resource.send(method)
        rescue => detail
            puts detail.backtrace if Puppet[:trace]
            resource.err "Failed to generate additional resources using '%s': %s" % [method, detail]
        end
        return [] unless made
        made = [made] unless made.is_a?(Array)
        made.uniq.find_all do |res|
            begin
                res.tag(*resource.tags)
                @catalog.add_resource(res) do |r|
                    r.finish
                    make_parent_child_relationship(resource, [r])
                end
                true
            rescue Puppet::Resource::Catalog::DuplicateResourceError
                res.info "Duplicate generated resource; skipping"
                false
            end
        end
    end

    # Collect any dynamically generated resources.  This method is called
    # before the transaction starts.
    def generate
        list = @catalog.vertices
        newlist = []
        while ! list.empty?
            list.each do |resource|
                newlist += generate_additional_resources(resource, :generate)
            end
            list = newlist
            newlist = []
        end
    end

    def add_metrics_to_report(report)
        @resourcemetrics[:failed] = @failures.find_all do |name, num|
            num > 0
        end.length

        # Get the total time spent
        @timemetrics[:total] = @timemetrics.inject(0) do |total, vals|
            total += vals[1]
            total
        end

        # Add all of the metrics related to resource count and status
        report.newmetric(:resources, @resourcemetrics)

        # Record the relative time spent in each resource.
        report.newmetric(:time, @timemetrics)

        # Then all of the change-related metrics
        report.newmetric(:changes, :total => @changes.length)
        return report
    end

    # Should we ignore tags?
    def ignore_tags?
        ! (@catalog.host_config? or Puppet[:name] == "puppet")
    end

    # this should only be called by a Puppet::Type::Component resource now
    # and it should only receive an array
    def initialize(catalog)
        @catalog = catalog

        @resourcemetrics = {
            :total => @catalog.vertices.length,
            :out_of_sync => 0,    # The number of resources that had changes
            :applied => 0,        # The number of resources fixed
            :skipped => 0,      # The number of resources skipped
            :restarted => 0,    # The number of resources triggered
            :failed_restarts => 0, # The number of resources that fail a trigger
            :scheduled => 0     # The number of resources scheduled
        }

        # Metrics for distributing times across the different types.
        @timemetrics = Hash.new(0)

        # The changes we're performing
        @changes = []

        # The resources that have failed and the number of failures each.  This
        # is used for skipping resources because of failed dependencies.
        @failures = Hash.new do |h, key|
            h[key] = 0
        end

        @report = Report.new

        @event_manager = Puppet::Transaction::EventManager.new(self)

        @resource_harness = Puppet::Transaction::ResourceHarness.new(self)
    end

    # Prefetch any providers that support it.  We don't support prefetching
    # types, just providers.
    def prefetch
        prefetchers = {}
        @catalog.vertices.each do |resource|
            if provider = resource.provider and provider.class.respond_to?(:prefetch)
                prefetchers[provider.class] ||= {}
                prefetchers[provider.class][resource.name] = resource
            end
        end

        # Now call prefetch, passing in the resources so that the provider instances can be replaced.
        prefetchers.each do |provider, resources|
            Puppet.debug "Prefetching %s resources for %s" % [provider.name, provider.resource_type.name]
            begin
                provider.prefetch(resources)
            rescue => detail
                if Puppet[:trace]
                    puts detail.backtrace
                end
                Puppet.err "Could not prefetch %s provider '%s': %s" % [provider.resource_type.name, provider.name, detail]
            end
        end
    end

    # Prepare to evaluate the resources in a transaction.
    def prepare
        # Now add any dynamically generated resources
        generate()

        # Then prefetch.  It's important that we generate and then prefetch,
        # so that any generated resources also get prefetched.
        prefetch()

        # This will throw an error if there are cycles in the graph.
        @sorted_resources = relationship_graph.topsort
    end

    def relationship_graph
        catalog.relationship_graph
    end

    # Send off the transaction report.
    def send_report
        begin
            report = generate_report()
        rescue => detail
            Puppet.err "Could not generate report: %s" % detail
            return
        end

        if Puppet[:summarize]
            puts report.summary
        end

        if Puppet[:report]
            begin
                report.save()
            rescue => detail
                Puppet.err "Reporting failed: %s" % detail
            end
        end
    end

    def add_resource_status(status)
        report.add_resource_status status
    end

    def resource_status(resource)
        report.resource_statuses[resource.to_s]
    end

    # Roll all completed changes back.
    def rollback
        @changes.reverse.collect do |change|
            begin
                event = change.backward
            rescue => detail
                Puppet.err("%s rollback failed: %s" % [change,detail])
                if Puppet[:trace]
                    puts detail.backtrace
                end
                next
                # at this point, we would normally do error handling
                # but i haven't decided what to do for that yet
                # so just record that a sync failed for a given resource
                #@@failures[change.property.parent] += 1
                # this still could get hairy; what if file contents changed,
                # but a chmod failed?  how would i handle that error? dern
            end

            # And queue the events
            event_manager.queue_event(change.resource, event)

            # Now check to see if there are any events for this child.
            event_manager.process_events(change.property.resource)
        end
    end

    # Is the resource currently scheduled?
    def scheduled?(resource)
        self.ignoreschedules or resource.scheduled?
    end

    # Should this resource be skipped?
    def skip?(resource)
        skip = false
        if missing_tags?(resource)
            resource.debug "Not tagged with %s" % tags.join(", ")
        elsif ! scheduled?(resource)
            resource.debug "Not scheduled"
        elsif failed_dependencies?(resource)
            resource.warning "Skipping because of failed dependencies"
        elsif resource.virtual?
            resource.debug "Skipping because virtual"
        else
            return false
        end
        return true
    end

    # The tags we should be checking.
    def tags
        unless defined? @tags
            self.tags = Puppet[:tags]
        end

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
        not appropriately_tagged?(resource)
    end

    def appropriately_tagged?(resource)
        self.ignore_tags? or tags.empty? or resource.tagged?(*tags)
    end
end

require 'puppet/transaction/report'

