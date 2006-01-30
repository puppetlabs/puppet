# the class that actually walks our object/state tree, collects the changes,
# and performs them

# there are two directions of walking:
#   - first we recurse down the tree and collect changes
#   - then we walk back up the tree through 'refresh' after the changes

require 'puppet'
require 'puppet/statechange'

#---------------------------------------------------------------
module Puppet
class Transaction
    attr_accessor :toplevel, :component

    #---------------------------------------------------------------
    # a bit of a gross hack; a global list of objects that have failed to sync,
    # so that we can verify during later syncs that our dependencies haven't
    # failed
    def Transaction.init
        @@failures = Hash.new(0)
        Puppet::Metric.init
        @@changed = []
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # for now, just store the changes for executing linearly
    # later, we might execute them as we receive them
    def change(change)
        @changes.push change
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # okay, here's the deal:
    # a given transaction maps directly to a component, and each transaction
    # will only ever receive changes from its respective component
    # so, when looking for subscribers, we need to first see if the object
    # that actually changed had any direct subscribers
    # then, we need to pass the event to the object's containing component,
    # to see if it or any of its parents have subscriptions on the event
    def evaluate
        Puppet.debug "Beginning transaction %s with %s changes" %
            [self.object_id, @changes.length]

        now = Time.now
        events = @changes.collect { |change|
            if change.is_a?(Puppet::StateChange)
                change.transaction = self
                events = nil
                begin
                    # use an array, so that changes can return more than one
                    # event if they want
                    events = [change.forward].flatten.reject { |e| e.nil? }
                    #@@changed.push change.state.parent
                rescue => detail
                    change.state.err "change from %s to %s failed: %s" %
                        [change.state.is_to_s, change.state.should_to_s, detail]
                    #Puppet.err("%s failed: %s" % [change.to_s,detail])
                    if Puppet[:debug]
                        puts detail.backtrace
                    end
                    next
                    # FIXME this should support using onerror to determine
                    # behaviour; or more likely, the client calling us
                    # should do so
                end

                # This is kinda lame, because it can result in the same
                # object being modified multiple times, but that's difficult
                # to avoid as long as we're syncing each state individually.
                change.state.parent.cache(:synced, now)

                unless events.nil? or (events.is_a?(Array) and events.empty?)
                    change.changed = true
                end
                events
            else
                puts caller
                raise Puppet::DevError,
                    "Transactions cannot handle objects of type %s" % change.class
            end
        }.flatten.reject { |event|
            event.nil?
        }

        #@triggerevents = []
        events.each { |event|
            object = event.source
            #Puppet::Event::Subscriptions.propagate(object, event, self)
            object.propagate(event, self)
        }

        #events += @triggerevents
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # this should only be called by a Puppet::Container object now
    # and it should only receive an array
    def initialize(objects)
        @objects = objects
        @toplevel = false

        @triggered = Hash.new { |hash, key|
            hash[key] = Hash.new(0)
        }

        # of course, this won't work on the second run
        unless defined? @@failures
            @toplevel = true
            self.class.init
        end
        # change collection is in-band, and message generation is out-of-band
        # of course, exception raising is also out-of-band
        now = Time.now.to_i
        @changes = @objects.find_all { |child|
            child.scheduled?
        }.collect { |child|
            # these children are all Puppet::Type instances
            # not all of the children will return a change, and Containers
            # return transactions
            #ary = child.evaluate
            #ary
            child.evaluate
        }.flatten.reject { |child|
            child.nil? # remove empties
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def rollback
        events = @changes.reverse.collect { |change|
            if change.is_a?(Puppet::StateChange)
                # skip changes that were never actually run
                unless change.changed
                    Puppet.debug "%s was not changed" % change.to_s
                    next
                end
                #change.transaction = self
                begin
                    change.backward
                    #@@changed.push change.state.parent
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
            elsif change.is_a?(Puppet::Transaction)
                raise Puppet::DevError, "Got a sub-transaction"
                # yay, recursion
                change.rollback
            else
                raise Puppe::DevError,
                    "Transactions cannot handle objects of type %s" % child.class
            end
        }.flatten.reject { |e| e.nil? }

        #@triggerevents = []
        events.each { |event|
            object = event.source
            object.propagate(event, self)
        }

        #events += @triggerevents
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def triggered(object, method)
        @triggered[object][method] += 1
        #@triggerevents << ("%s_%sed" % [object.class.name.to_s, method.to_s]).intern
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def triggered?(object, method)
        @triggered[object][method]
    end
    #---------------------------------------------------------------
end
end
#---------------------------------------------------------------

# $Id$
