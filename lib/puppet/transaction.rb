#!/usr/local/bin/ruby -w

# $Id$

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
        Puppet.debug "executing %s changes " % @changes.length

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
                    Puppet.err("%s failed: %s" % [change,detail])
                    next
                    # FIXME this should support using onerror to determine behaviour
                end

                if events.nil?
                    Puppet.debug "No events returned?"
                end
                events
            elsif change.is_a?(Puppet::Transaction)
                change.evaluate
            else
                raise "Transactions cannot handle objects of type %s" % child.class
            end
        }.flatten.reject { |event|
            event.nil?
        }

        @triggerevents = []
        events.each { |event|
            object = event.source
            object.propagate(event)
        }

        events += @triggerevents
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
        @changes = @objects.collect { |child|
            # these children are all Puppet::Type instances
            # not all of the children will return a change, and Containers
            # return transactions
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
                next unless change.run
                #change.transaction = self
                begin
                    change.backward
                    #@@changed.push change.state.parent
                rescue => detail
                    Puppet.err("%s rollback failed: %s" % [change,detail])
                    next
                    # at this point, we would normally do error handling
                    # but i haven't decided what to do for that yet
                    # so just record that a sync failed for a given object
                    #@@failures[change.state.parent] += 1
                    # this still could get hairy; what if file contents changed,
                    # but a chmod failed?  how would i handle that error? dern
                end
            elsif change.is_a?(Puppet::Transaction)
                # yay, recursion
                change.rollback
            else
                raise "Transactions cannot handle objects of type %s" % child.class
            end
        }.flatten.reject { |e| e.nil? }

        @triggerevents = []
        events.each { |event|
            object = event.source
            object.propagate(event)
        }

        events += @triggerevents
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def triggered(object, method)
        @triggered[object][method] += 1
        @triggerevents << ("%s_%sed" % [object.class.name.to_s, method.to_s]).intern
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
