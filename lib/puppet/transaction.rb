# the class that actually walks our object/state tree, collects the changes,
# and performs them

require 'puppet'
require 'puppet/statechange'

module Puppet
class Transaction
    attr_accessor :toplevel, :component, :objects, :tags, :ignoreschedules

    Puppet.config.setdefaults(:transaction,
        :tags => ["", "Tags to use to find objects.  If this is set, then
            only objects tagged with the specified tags will be applied.
            Values must be comma-separated."]
    )

    # a bit of a gross hack; a global list of objects that have failed to sync,
    # so that we can verify during later syncs that our dependencies haven't
    # failed
    def Transaction.init
        @@failures = Hash.new(0)
        Puppet::Metric.init
    end

    # Apply all changes for a child, returning a list of the events
    # generated.
    def apply(child)
        # First make sure there are no failed dependencies
        child.eachdependency do |dep|
            skip = false
            if @failures[dep] > 0
                child.notice "Dependency %s[%s] has %s failures" %
                    [dep.class.name, dep.name, @failures[dep]]
                skip = true
            end

            if skip
                child.warning "Skipping because of failed dependencies"
                return []
            end
        end

        begin
            changes = child.evaluate
        rescue => detail
            if Puppet[:debug]
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
                change.state.err "change from %s to %s failed: %s" %
                    [change.state.is_to_s, change.state.should_to_s, detail]
                #Puppet.err("%s failed: %s" % [change.to_s,detail])
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
            end

            events
        }.flatten.reject { |e| e.nil? }

        unless changes.empty?
            # Record when we last synced
            child.cache(:synced, Time.now)
        end

        childevents
    end

    # for now, just store the changes for executing linearly
    # later, we might execute them as we receive them
    def change(change)
        @changes.push change
    end

    # Find all of the changed objects.
    def changed?
        @changes.find_all { |change| change.changed }.collect { |change|
            change.state.parent
        }.uniq
    end

    # Collect all of the targets for the list of events.  This is an unintuitive
    # method because it recurses up through the source the event.
    def collecttargets(events)
        events.each do |event|
            source = event.source
            start = source

            while source
                Puppet::Event::Subscription.targets_of(event, source) do |sub|
                    start.info "Scheduling %s of %s[%s]" %
                        [sub.callback, sub.target.class.name, sub.target.name]
                    @targets[sub.target][event] = sub
                end

                source = source.parent
            end
        end
    end

    # This method does all the actual work of running a transaction.  It
    # collects all of the changes, executes them, and responds to any
    # necessary events.
    def evaluate
        #Puppet.debug "Beginning transaction %s with %s changes" %
        #    [self.object_id, @changes.length]

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

        allevents = @objects.collect { |child|
            events = nil
            if (tags.nil? or child.tagged?(tags))
                if self.ignoreschedules or child.scheduled?
                    # Perform the actual changes
                    events = apply(child)

                    # Collect the targets of any subscriptions to those events
                    collecttargets(events)
                else
                    child.debug "Not scheduled"
                end
            else
                child.debug "Not tagged with %s" % tags.join(", ")
            end

            # Now check to see if there are any events for this child
            trigger(child)

            # And return the events for collection
            events
        }.flatten.reject { |e| e.nil? }

        Puppet.debug "Finishing transaction %s with %s changes" %
            [self.object_id, @count]

        # Currently, we return the list of events, but really, this
        # should be some kind of report
        allevents
    end

    # Determine whether a given object has failed.
    def failed?(obj)
        @failures[obj] > 0
    end

    # this should only be called by a Puppet::Container object now
    # and it should only receive an array
    def initialize(objects)
        @objects = objects
        @toplevel = false

        @triggered = Hash.new { |hash, key|
            hash[key] = Hash.new(0)
        }

        @targets = Hash.new do |hash, key|
            hash[key] = {}
        end

        # of course, this won't work on the second run
        unless defined? @@failures
            @toplevel = true
            self.class.init
        end

        @changes = []

        @failures = Hash.new do |h, key|
            h[key] = 0
        end
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
                if Puppet[:debug]
                    puts detail.backtrace
                end
                next
                # at this point, we would normally do error handling
                # but i haven't decided what to do for that yet
                # so just record that a sync failed for a given object
                #@@failures[change.state.parent] += 1
                # this still could get hairy; what if file contents changed,
                # but a chmod failed?  how would i handle that error? dern
            end

            collecttargets(events)

            # Now check to see if there are any events for this child.
            # Kind of hackish, since going backwards goes a change at a
            # time, not a child at a time.
            trigger(change.state.parent)

            # And return the events for collection
            events
        }.flatten.reject { |e| e.nil? }
    end

    # Trigger any subscriptions to a child.  This does an upwardly recursive
    # search -- it triggers the passed object, but also the object's parent
    # and so on up the tree.
    def trigger(child)
        obj = child
        callbacks = Hash.new { |hash, key| hash[key] = [] }
        sources = Hash.new { |hash, key| hash[key] = [] }

        while obj
            if @targets.include?(obj)
                callbacks.clear
                sources.clear
                @targets[obj].each do |event, sub|
                    # Collect all of the subs for each callback
                    callbacks[sub.callback] << sub

                    # And collect the sources for logging
                    sources[event.source] << sub.callback
                end

                sources.each do |source, callbacklist|
                    obj.debug "%s[%s] results in triggering %s" %
                        [source.class.name, source.name, callbacklist.join(", ")]
                end

                callbacks.each do |callback, subs|
                    obj.info "Triggering '%s' from %s dependencies" %
                        [callback, subs.length]
                    # At this point, just log failures, don't try to react
                    # to them in any way.
                    begin
                        obj.send(callback)
                    rescue => detail
                        obj.err "Failed to call %s on %s: %s" %
                            [callback, obj, detail]

                        if Puppet[:debug]
                            puts detail.backtrace
                        end
                    end

                    triggered(obj, callback)
                end
            end

            obj = obj.parent
        end
    end

    def triggered(object, method)
        @triggered[object][method] += 1
    end

    def triggered?(object, method)
        @triggered[object][method]
    end
end
end

# $Id$
