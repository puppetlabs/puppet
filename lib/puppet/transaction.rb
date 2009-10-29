# the class that actually walks our resource/property tree, collects the changes,
# and performs them

require 'puppet'
require 'puppet/util/tagging'

class Puppet::Transaction
    require 'puppet/transaction/change'
    require 'puppet/transaction/event'

    attr_accessor :component, :catalog, :ignoreschedules
    attr_accessor :sorted_resources, :configurator

    # The list of events generated in this transaction.
    attr_reader :events

    # Mostly only used for tests
    attr_reader :resourcemetrics, :changes

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

    # Apply all changes for a resource, returning a list of the events
    # generated.
    def apply(resource)
        begin
            changes = resource.evaluate
        rescue => detail
            puts detail.backtrace if Puppet[:trace]

            resource.err "Failed to retrieve current state of resource: %s" % detail

            # Mark that it failed
            @failures[resource] += 1

            # And then return
            return
        end

        changes = [changes] unless changes.is_a?(Array)

        @resourcemetrics[:out_of_sync] += 1 if changes.length > 0

        return if changes.empty? or ! allow_processing?(resource, changes)

        apply_changes(resource, changes)

        # If there were changes and the resource isn't in noop mode...
        unless changes.empty? or resource.noop
            # Record when we last synced
            resource.cache(:synced, Time.now)

            # Flush, if appropriate
            if resource.respond_to?(:flush)
                resource.flush
            end
        end
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

    # Are we deleting this resource?
    def deleting?(changes)
        changes.detect { |change|
            change.property.name == :ensure and change.should == :absent
        }
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
        process_events(resource)
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

        # A bit of hackery here -- if skipcheck is true, then we're the
        # top-level resource.  If that's the case, then make sure all of
        # the changes list this resource as a proxy.  This is really only
        # necessary for rollback, since we know the generating resource
        # during forward changes.
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

        allevents = @sorted_resources.collect { |resource|
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
        }.flatten.reject { |e| e.nil? }

        Puppet.debug "Finishing transaction #{object_id} with #{@changes.length} changes"
    end

    # Determine whether a given resource has failed.
    def failed?(obj)
        if @failures[obj] > 0
            return @failures[obj]
        else
            return false
        end
    end

    # Does this resource have any failed dependencies?
    def failed_dependencies?(resource)
        # First make sure there are no failed dependencies.  To do this,
        # we check for failures in any of the vertexes above us.  It's not
        # enough to check the immediate dependencies, which is why we use
        # a tree from the reversed graph.
        skip = false
        deps = relationship_graph.dependencies(resource)
        deps.each do |dep|
            if fails = failed?(dep)
                resource.notice "Dependency %s[%s] has %s failures" %
                    [dep.class.name, dep.name, @failures[dep]]
                skip = true
            end
        end

        return skip
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

        report.time = Time.now
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

        @event_queues = {}

        # The changes we're performing
        @changes = []

        # The complete list of events generated.
        @events = []

        # The resources that have failed and the number of failures each.  This
        # is used for skipping resources because of failed dependencies.
        @failures = Hash.new do |h, key|
            h[key] = 0
        end

        @report = Report.new
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

    # Respond to any queued events for this resource.
    def process_events(resource)
        restarted = false
        queued_events(resource) do |callback, events|
            r = process_callback(resource, callback, events)
            restarted ||= r
        end

        if restarted
            queue_event(resource, Puppet::Transaction::Event.new(:restarted, resource))

            @resourcemetrics[:restarted] += 1
        end
    end

    # Queue events for other resources to respond to.  All of these events have
    # to be from the same resource.
    def queue_event(resource, event)
        @events << event

        # Collect the targets of any subscriptions to those events.  We pass
        # the parent resource in so it will override the source in the events,
        # since eval_generated children can't have direct relationships.
        relationship_graph.matching_edges(events, resource).each do |edge|
            next unless method = edge.callback
            next unless edge.target.respond_to?(method)

            queue_event_for_resource(resource, edge.target, method, event)
        end

        if resource.self_refresh? and ! resource.deleting?
            queue_event_for_resource(resource, resource, :refresh, event)
        end
    end

    def queue_event_for_resource(source, target, callback, event)
        source.info "Scheduling #{callback} of #{target}"

        @event_queues[target] ||= {}
        @event_queues[target][callback] ||= []
        @event_queues[target][callback] << event
    end

    def queued_events(resource)
        return unless callbacks = @event_queues[resource]
        callbacks.each do |callback, events|
            yield callback, events
        end
    end

    def relationship_graph
        catalog.relationship_graph
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
            queue_event(change.resource, event)

            # Now check to see if there are any events for this child.
            process_events(change.property.resource)
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

    private

    def apply_change(resource, change)
        @changes << change

        event = change.forward

        if event.status == "success"
            @resourcemetrics[:applied] += 1
        else
            @failures[resource] += 1
        end
        queue_event(resource, event)
    end

    def process_callback(resource, callback, events)
        process_noop_events(resource, callback, events) and return false if events.detect { |e| e.name == :noop }
        resource.send(callback)

        resource.notice "Triggered '#{callback}' from #{events.length} events"
        return true
    rescue => detail
        resource.err "Failed to call #{callback}: #{detail}"

        @resourcemetrics[:failed_restarts] += 1
        puts detail.backtrace if Puppet[:trace]
        return false
    end

    def process_noop_events(resource, callback, events)
        resource.notice "Would have triggered '#{callback}' from #{events.length} events"

        # And then add an event for it.
        queue_event(resource, Puppet::Transaction::Event.new(:noop, resource))
        true # so the 'and if' works
    end
end

require 'puppet/transaction/report'

