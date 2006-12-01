# the class that actually walks our resource/state tree, collects the changes,
# and performs them

require 'puppet'
require 'puppet/statechange'

module Puppet
class Transaction
    attr_accessor :component, :resources, :tags, :ignoreschedules, :ignoretags
    attr_accessor :relgraph

    include Puppet::Util

    Puppet.config.setdefaults(:transaction,
        :tags => ["", "Tags to use to find resources.  If this is set, then
            only resources tagged with the specified tags will be applied.
            Values must be comma-separated."]
    )

    # Add some additional times for reporting
    def addtimes(hash)
        hash.each do |name, num|
            @timemetrics[name] = num
        end
    end

    # Apply all changes for a child, returning a list of the events
    # generated.
    def apply(child)
        child.info "applying"
        # First make sure there are no failed dependencies.  To do this,
        # we check for failures in any of the vertexes above us.  It's not
        # enough to check the immediate dependencies, which is why we use
        # a tree from the reversed graph.
        p @relgraph.vertices.collect { |v| v.ref }
        @relgraph.reversal.tree_from_vertex(child, :dfs).keys.each do |dep|
            skip = false
            if fails = failed?(dep)
                child.notice "Dependency %s[%s] has %s failures" %
                    [dep.class.name, dep.name, @failures[dep]]
                skip = true
            end

            if skip
                child.warning "Skipping because of failed dependencies"
                @resourcemetrics[:skipped] += 1
                return []
            end
        end

        begin
            changes = child.evaluate
        rescue => detail
            if Puppet[:trace]
                puts detail.backtrace
            end

            child.err "Failed to retrieve current state: %s" % detail

            # Mark that it failed
            @failures[child] += 1

            # And then return
            return []
        end

        unless changes.is_a? Array
            changes = [changes]
        end

        if changes.length > 0
            @resourcemetrics[:out_of_sync] += 1
        end

        childevents = changes.collect { |change|
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
                change.state.err "change from %s to %s failed: %s" %
                    [change.state.is_to_s, change.state.should_to_s, detail]
                @failures[child] += 1
                next
                # FIXME this should support using onerror to determine
                # behaviour; or more likely, the client calling us
                # should do so
            end

            # Mark that our change happened, so it can be reversed
            # if we ever get to that point
            unless events.nil? or (events.is_a?(Array) and events.empty?)
                change.changed = true
                @resourcemetrics[:applied] += 1
            end

            events
        }.flatten.reject { |e| e.nil? }

        unless changes.empty?
            # Record when we last synced
            child.cache(:synced, Time.now)

            # Flush, if appropriate
            if child.respond_to?(:flush)
                child.flush
            end
        end

        childevents
    end

    # Find all of the changed resources.
    def changed?
        @changes.find_all { |change| change.changed }.collect { |change|
            change.state.parent
        }.uniq
    end

    # This method does all the actual work of running a transaction.  It
    # collects all of the changes, executes them, and responds to any
    # necessary events.
    def evaluate
        @count = 0

        # Allow the tags to be overriden
        tags = self.tags || Puppet[:tags]
        if tags.nil? or tags == ""
            tags = nil
        else
            tags = [tags] unless tags.is_a? Array
            tags = tags.collect do |tag|
                tag.split(/\s*,\s*/)
            end.flatten
        end

        # Start logging.
        Puppet::Log.newdestination(@report)

        prefetch()
        
        # Now add any dynamically generated resources
        generate()
        
        # Create a relationship graph from our resource graph
        @relgraph = relationship_graph
        
        @relgraph.to_jpg("relations")

        begin
            allevents = @relgraph.topsort.collect { |child|
                events = []
                if (self.ignoretags or tags.nil? or child.tagged?(tags))
                    if self.ignoreschedules or child.scheduled?
                        @resourcemetrics[:scheduled] += 1
                        # Perform the actual changes

                        seconds = thinmark do
                            events = apply(child)
                        end

                        # Keep track of how long we spend in each type of resource
                        @timemetrics[child.class.name] += seconds
                    else
                        child.debug "Not scheduled"
                    end
                else
                    child.debug "Not tagged with %s" % tags.join(", ")
                end

                # Check to see if there are any events for this child
                if triggedevents = trigger(child)
                    events += triggedevents
                end

                # Collect the targets of any subscriptions to those events
                @relgraph.matching_edges(events).each do |edge|
                    @targets[edge.target] << edge
                end

                # And return the events for collection
                events
            }.flatten.reject { |e| e.nil? }
        ensure
            # And then close the transaction log.
            Puppet::Log.close(@report)
        end

        Puppet.debug "Finishing transaction %s with %s changes" %
            [self.object_id, @count]

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
    
    # Collect any dynamically generated resources.
    def generate
        list = @resources.vertices
        newlist = []
        while ! list.empty?
            list.each do |resource|
                if resource.respond_to?(:generate)
                    made = resource.generate
                    unless made.is_a?(Array)
                        made = [made]
                    end
                    made.each do |res|
                        @resources.add_vertex!(res)
                        newlist << res
                    end
                end
            end
            list.clear
            list = newlist
            newlist = []
        end
    end

    # this should only be called by a Puppet::Type::Component resource now
    # and it should only receive an array
    def initialize(resources)
        @resources = resources.to_graph

        @resourcemetrics = {
            :total => @resources.vertices.length,
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
    end

    # Prefetch any providers that support it.  We don't support prefetching
    # types, just providers.
    def prefetch
        @resources.collect { |obj|
            if pro = obj.provider
                pro.class
            else
                nil
            end
        }.reject { |o| o.nil? }.uniq.each do |klass|
            # XXX We need to do something special here in case of failure.
            if klass.respond_to?(:prefetch)
                klass.prefetch
            end
        end
    end
    
    # Create a graph of all of the relationships in our resource graph.
    def relationship_graph
        graph = Puppet::PGraph.new
        
        # First create the dependency graph
        @resources.vertices.each do |vertex|
            graph.add_vertex!(vertex)
            vertex.builddepends.each do |edge|
                graph.add_edge!(edge)
            end
        end
        
        # Then splice in the container information
        graph.splice!(@resources, Puppet::Type::Component)
        
        # Lastly, add in any autorequires
        graph.vertices.each do |vertex|
            vertex.autorequire.each do |edge|
                unless graph.edge?(edge)
                    graph.add_edge!(edge)
                end
            end
        end
        
        return graph
    end

    # Generate a transaction report.
    def report
        @resourcemetrics[:failed] = @failures.find_all do |name, num|
            num > 0
        end.length

        # Get the total time spent
        @timemetrics[:total] = @timemetrics.inject(0) do |total, vals|
            total += vals[1]
            total
        end

        # Unfortunately, RRD does not deal well with changing lists of values,
        # so we have to pick a list of values and stick with it.  In this case,
        # that means we record the total time, the config time, and that's about
        # it.  We should probably send each type's time as a separate metric.
        @timemetrics.dup.each do |name, value|
            if Puppet::Type.type(name)
                @timemetrics.delete(name)
            end
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
                #@@failures[change.state.parent] += 1
                # this still could get hairy; what if file contents changed,
                # but a chmod failed?  how would i handle that error? dern
            end
            
            @relgraph.matching_edges(events).each do |edge|
                @targets[edge.target] << edge
            end

            # Now check to see if there are any events for this child.
            # Kind of hackish, since going backwards goes a change at a
            # time, not a child at a time.
            trigger(change.state.parent)

            # And return the events for collection
            events
        }.flatten.reject { |e| e.nil? }
    end

    # Trigger any subscriptions to a child.  This does an upwardly recursive
    # search -- it triggers the passed resource, but also the resource's parent
    # and so on up the tree.
    def trigger(child)
        obj = child
        callbacks = Hash.new { |hash, key| hash[key] = [] }
        sources = Hash.new { |hash, key| hash[key] = [] }

        trigged = []
        while obj
            if @targets.include?(obj)
                callbacks.clear
                sources.clear
                @targets[obj].each do |edge|
                    # Some edges don't have callbacks
                    next unless edge.callback
                    
                    # Collect all of the subs for each callback
                    callbacks[edge.callback] << edge

                    # And collect the sources for logging
                    sources[edge.source] << edge.callback
                end

                sources.each do |source, callbacklist|
                    obj.debug "%s[%s] results in triggering %s" %
                        [source.class.name, source.name, callbacklist.join(", ")]
                end

                callbacks.each do |callback, subs|
                    message = "Triggering '%s' from %s dependencies" %
                        [callback, subs.length]
                    obj.notice message
                    # At this point, just log failures, don't try to react
                    # to them in any way.
                    begin
                        obj.send(callback)
                        @resourcemetrics[:restarted] += 1
                    rescue => detail
                        obj.err "Failed to call %s on %s: %s" %
                            [callback, obj, detail]

                        @resourcemetrics[:failed_restarts] += 1

                        if Puppet[:trace]
                            puts detail.backtrace
                        end
                    end

                    # And then add an event for it.
                    trigged << Puppet::Event.new(
                        :event => :triggered,
                        :transaction => self,
                        :source => obj,
                        :message => message
                    )

                    triggered(obj, callback)
                end
            end

            obj = obj.parent
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

# $Id$
