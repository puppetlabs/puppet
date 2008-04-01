# the class that actually walks our resource/property tree, collects the changes,
# and performs them

require 'puppet'
require 'puppet/propertychange'

module Puppet
class Transaction
    attr_accessor :component, :catalog, :ignoreschedules
    attr_accessor :sorted_resources, :configurator

    # The report, once generated.
    attr_reader :report

    # The list of events generated in this transaction.
    attr_reader :events
    
    include Puppet::Util

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
            if Puppet[:trace]
                puts detail.backtrace
            end

            resource.err "Failed to retrieve current state of resource: %s" % detail

            # Mark that it failed
            @failures[resource] += 1

            # And then return
            return []
        end

        changes = [changes] unless changes.is_a?(Array)

        if changes.length > 0
            @resourcemetrics[:out_of_sync] += 1
        end

        return [] if changes.empty? or ! allow_processing?(resource, changes)

        resourceevents = apply_changes(resource, changes)

        # If there were changes and the resource isn't in noop mode...
        unless changes.empty? or resource.noop
            # Record when we last synced
            resource.cache(:synced, Time.now)

            # Flush, if appropriate
            if resource.respond_to?(:flush)
                resource.flush
            end
            
            # And set a trigger for refreshing this resource if it's a
            # self-refresher
            if resource.self_refresh? and ! resource.deleting?
                # Create an edge with this resource as both the source and
                # target.  The triggering method treats these specially for
                # logging.
                events = resourceevents.collect { |e| e.event }
                set_trigger(Puppet::Relationship.new(resource, resource, :callback => :refresh, :event => events))
            end
        end

        resourceevents
    end

    # Apply each change in turn.
    def apply_changes(resource, changes)
        changes.collect { |change|
            @changes << change
            @count += 1
            change.transaction = self
            events = nil
            begin
                # use an array, so that changes can return more than one
                # event if they want
                events = [change.forward].flatten.reject { |e| e.nil? }
            rescue => detail
                if Puppet[:trace]
                    puts detail.backtrace
                end
                change.property.err "change from %s to %s failed: %s" %
                    [change.property.is_to_s(change.is), change.property.should_to_s(change.should), detail]
                @failures[resource] += 1
                next
                # FIXME this should support using onerror to determine
                # behaviour; or more likely, the client calling us
                # should do so
            end

            # Mark that our change happened, so it can be reversed
            # if we ever get to that point
            unless events.nil? or (events.is_a?(Array) and (events.empty?) or events.include?(:noop))
                change.changed = true
                @resourcemetrics[:applied] += 1
            end

            events
        }.flatten.reject { |e| e.nil? }
    end

    # Find all of the changed resources.
    def changed?
        @changes.find_all { |change| change.changed }.collect { |change|
            unless change.property.resource
                raise "No resource for %s" % change.inspect
            end
            change.property.resource
        }.uniq
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
    def copy_relationships(resource, children)
        depthfirst = resource.depthfirst?
        
        children.each do |gen_child|
            if depthfirst
                edge = [gen_child, resource]
            else
                edge = [resource, gen_child]
            end
            relationship_graph.add_resource(gen_child) unless relationship_graph.resource(gen_child.ref)

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
        if resource.respond_to?(:eval_generate)
            begin
                children = resource.eval_generate
            rescue => detail
                if Puppet[:trace]
                    puts detail.backtrace
                end
                resource.err "Failed to generate additional resources during transaction: %s" %
                    detail
                return nil
            end
            
            if children
                children.each { |child| child.finish }
                @generated += children
                return children
            end
        end
    end
    
    # Evaluate a single resource.
    def eval_resource(resource, checkskip = true)
        events = []
        
        if resource.is_a?(Puppet::Type::Component)
            raise Puppet::DevError, "Got a component to evaluate"
        end
        
        if checkskip and skip?(resource)
            @resourcemetrics[:skipped] += 1
        else
            @resourcemetrics[:scheduled] += 1
            
            changecount = @changes.length
            
            # We need to generate first regardless, because the recursive
            # actions sometimes change how the top resource is applied.
            children = eval_generate(resource)
            
            if children and resource.depthfirst?
                children.each do |child|
                    # The child will never be skipped when the parent isn't
                    events += eval_resource(child, false)
                end
            end

            # Perform the actual changes
            seconds = thinmark do
                events += apply(resource)
            end

            if children and ! resource.depthfirst?
                children.each do |child|
                    events += eval_resource(child, false)
                end
            end

            # Create a child/parent relationship.  We do this after everything else because
            # we want explicit relationships to be able to override automatic relationships,
            # including this one.
            if children
                copy_relationships(resource, children)
            end
            
            # A bit of hackery here -- if skipcheck is true, then we're the
            # top-level resource.  If that's the case, then make sure all of
            # the changes list this resource as a proxy.  This is really only
            # necessary for rollback, since we know the generating resource
            # during forward changes.
            if children and checkskip
                @changes[changecount..-1].each { |change| change.proxy = resource }
            end

            # Keep track of how long we spend in each type of resource
            @timemetrics[resource.class.name] += seconds
        end

        # Check to see if there are any events for this resource
        if triggedevents = trigger(resource)
            events += triggedevents
        end

        # Collect the targets of any subscriptions to those events.  We pass
        # the parent resource in so it will override the source in the events,
        # since eval_generated children can't have direct relationships.
        relationship_graph.matching_edges(events, resource).each do |orig_edge|
            # We have to dup the label here, else we modify the original edge label,
            # which affects whether a given event will match on the next run, which is,
            # of course, bad.
            edge = orig_edge.class.new(orig_edge.source, orig_edge.target)
            label = orig_edge.label.dup
            label[:event] = events.collect { |e| e.event }
            edge.label = label
            set_trigger(edge)
        end

        # And return the events for collection
        events
    end

    # This method does all the actual work of running a transaction.  It
    # collects all of the changes, executes them, and responds to any
    # necessary events.
    def evaluate
        @count = 0

        # Start logging.
        Puppet::Util::Log.newdestination(@report)
        
        prepare()

        begin
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
        ensure
            # And then close the transaction log.
            Puppet::Util::Log.close(@report)
        end

        Puppet.debug "Finishing transaction %s with %s changes" %
            [self.object_id, @count]

        @events = allevents
        allevents
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
    
    # Collect any dynamically generated resources.
    def generate
        list = @catalog.vertices
        
        # Store a list of all generated resources, so that we can clean them up
        # after the transaction closes.
        @generated = []
        
        newlist = []
        while ! list.empty?
            list.each do |resource|
                if resource.respond_to?(:generate)
                    begin
                        made = resource.generate
                    rescue => detail
                        resource.err "Failed to generate additional resources: %s" %
                            detail
                    end
                    next unless made
                    unless made.is_a?(Array)
                        made = [made]
                    end
                    made.uniq!
                    made.each do |res|
                        @catalog.add_resource(res)
                        res.catalog = catalog
                        newlist << res
                        @generated << res
                        res.finish
                    end
                end
            end
            list.clear
            list = newlist
            newlist = []
        end
    end

    # Generate a transaction report.
    def generate_report
        @resourcemetrics[:failed] = @failures.find_all do |name, num|
            num > 0
        end.length

        # Get the total time spent
        @timemetrics[:total] = @timemetrics.inject(0) do |total, vals|
            total += vals[1]
            total
        end

        # Add all of the metrics related to resource count and status
        @report.newmetric(:resources, @resourcemetrics)

        # Record the relative time spent in each resource.
        @report.newmetric(:time, @timemetrics)

        # Then all of the change-related metrics
        @report.newmetric(:changes,
            :total => @changes.length
        )

        @report.time = Time.now

        return @report
    end

    # Should we ignore tags?
    def ignore_tags?
        ! (@catalog.host_config? or Puppet[:name] == "puppet")
    end

    # this should only be called by a Puppet::Type::Component resource now
    # and it should only receive an array
    def initialize(resources)
        if resources.is_a?(Puppet::Node::Catalog)
            @catalog = resources
        elsif resources.is_a?(Puppet::PGraph)
            raise "Transactions should get catalogs now, not PGraph"
        else
            raise "Transactions require catalogs"
        end

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

        # The number of resources that were triggered in this run
        @triggered = Hash.new { |hash, key|
            hash[key] = Hash.new(0)
        }

        # Targets of being triggered.
        @targets = Hash.new do |hash, key|
            hash[key] = []
        end

        # The changes we're performing
        @changes = []

        # The resources that have failed and the number of failures each.  This
        # is used for skipping resources because of failed dependencies.
        @failures = Hash.new do |h, key|
            h[key] = 0
        end

        @report = Report.new
        @count = 0
    end

    # Prefetch any providers that support it.  We don't support prefetching
    # types, just providers.
    def prefetch
        prefetchers = {}
        @catalog.vertices.each do |resource|
            if provider = resource.provider and provider.class.respond_to?(:prefetch)
                prefetchers[provider.class] ||= {}
                prefetchers[provider.class][resource.title] = resource
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
        prefetch()
    
        # Now add any dynamically generated resources
        generate()

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

        if Puppet[:rrdgraph] == true
            report.graph()
        end

        if Puppet[:summarize]
            puts report.summary
        end
        
        if Puppet[:report]
            begin
                reportclient().report(report)
            rescue => detail
                Puppet.err "Reporting failed: %s" % detail
            end
        end
    end

    def reportclient
        unless defined? @reportclient
            @reportclient = Puppet::Network::Client.report.new(
                :Server => Puppet[:reportserver]
            )
        end

        @reportclient
    end

    # Roll all completed changes back.
    def rollback
        @targets.clear
        @triggered.clear
        allevents = @changes.reverse.collect { |change|
            # skip changes that were never actually run
            unless change.changed
                Puppet.debug "%s was not changed" % change.to_s
                next
            end
            begin
                events = change.backward
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
            
            # FIXME This won't work right now.
            relationship_graph.matching_edges(events).each do |edge|
                @targets[edge.target] << edge
            end

            # Now check to see if there are any events for this child.
            # Kind of hackish, since going backwards goes a change at a
            # time, not a child at a time.
            trigger(change.property.resource)

            # And return the events for collection
            events
        }.flatten.reject { |e| e.nil? }
    end
    
    # Is the resource currently scheduled?
    def scheduled?(resource)
        self.ignoreschedules or resource.scheduled?
    end

    # Set an edge to be triggered when we evaluate its target.
    def set_trigger(edge)
        return unless method = edge.callback
        return unless edge.target.respond_to?(method)
        if edge.target.respond_to?(:ref)
            unless edge.source == edge.target
                edge.source.info "Scheduling %s of %s" % [edge.callback, edge.target.ref]
            end
        end
        @targets[edge.target] << edge
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
        else
            return false
        end
        return true
    end
    
    # The tags we should be checking.
    def tags
        unless defined? @tags
            tags = Puppet[:tags]
            if tags.nil? or tags == ""
                @tags = []
            else
                @tags = tags.split(/\s*,\s*/)
            end
        end
        
        @tags
    end

    def tags=(tags)
        tags = [tags] unless tags.is_a?(Array)
        @tags = tags
    end
    
    # Is this resource tagged appropriately?
    def missing_tags?(resource)
        return false if self.ignore_tags? or tags.empty?
        return true unless resource.tagged?(tags)
    end
    
    # Are there any edges that target this resource?
    def targeted?(resource)
        # The default value is a new array so we have to test the length of it.
        @targets.include?(resource) and @targets[resource].length > 0
    end

    # Trigger any subscriptions to a child.  This does an upwardly recursive
    # search -- it triggers the passed resource, but also the resource's parent
    # and so on up the tree.
    def trigger(resource)
        return nil unless targeted?(resource)
        callbacks = Hash.new { |hash, key| hash[key] = [] }

        trigged = []
        @targets[resource].each do |edge|
            # Collect all of the subs for each callback
            callbacks[edge.callback] << edge
        end

        callbacks.each do |callback, subs|
            noop = true
            subs.each do |edge|
                if edge.event.nil? or ! edge.event.include?(:noop)
                    noop = false
                end
            end

            if noop
                resource.notice "Would have triggered %s from %s dependencies" %
                    [callback, subs.length]

                # And then add an event for it.
                return [Puppet::Event.new(
                    :event => :noop,
                    :transaction => self,
                    :source => resource
                )]
            end

            if subs.length == 1 and subs[0].source == resource
                message = "Refreshing self"
            else
                message = "Triggering '%s' from %s dependencies" %
                    [callback, subs.length]
            end
            resource.notice message
            
            # At this point, just log failures, don't try to react
            # to them in any way.
            begin
                resource.send(callback)
                @resourcemetrics[:restarted] += 1
            rescue => detail
                resource.err "Failed to call %s on %s: %s" %
                    [callback, resource, detail]

                @resourcemetrics[:failed_restarts] += 1

                if Puppet[:trace]
                    puts detail.backtrace
                end
            end

            # And then add an event for it.
            trigged << Puppet::Event.new(
                :event => :triggered,
                :transaction => self,
                :source => resource
            )

            triggered(resource, callback)
        end

        if trigged.empty?
            return nil
        else
            return trigged
        end
    end

    def triggered(resource, method)
        @triggered[resource][method] += 1
    end

    def triggered?(resource, method)
        @triggered[resource][method]
    end
end
end

require 'puppet/transaction/report'

