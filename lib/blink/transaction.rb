#!/usr/local/bin/ruby -w

# $Id$

# the class that actually walks our object/state tree, collects the changes,
# and performs them

# there are two directions of walking:
#   - first we recurse down the tree and collect changes
#   - then we walk back up the tree through 'refresh' after the changes

require 'blink'
require 'blink/statechange'

#---------------------------------------------------------------
module Blink
class Transaction
    attr_accessor :toplevel, :component

    #---------------------------------------------------------------
    # a bit of a gross hack; a global list of objects that have failed to sync,
    # so that we can verify during later syncs that our dependencies haven't
    # failed
    def Transaction.init
        @@failures = Hash.new(0)
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
    # i don't need to worry about ordering, because it's not possible to specify
    # an object as a dependency unless it's already been mentioned within the language
    # thus, an object gets defined, then mentioned as a dependency, and the objects
    # are synced in that order automatically
    def evaluate
        Blink.notice "executing %s changes or transactions" % @changes.length

        return @changes.collect { |change|
            if change.is_a?(Blink::StateChange)
                change.transaction = self
                events = nil
                begin
                    events = [change.forward].flatten
                    #@@changed.push change.state.parent
                rescue => detail
                    Blink.error("%s failed: %s" % [change,detail])
                    # at this point, we would normally do error handling
                    # but i haven't decided what to do for that yet
                    # so just record that a sync failed for a given object
                    #@@failures[change.state.parent] += 1
                    # this still could get hairy; what if file contents changed,
                    # but a chmod failed?  how would i handle that error? dern
                end

                # first handle the subscriptions on individual objects
                events.each { |event|
                    change.state.parent.subscribers?(event).each { |sub|
                        sub.trigger(self)
                    }
                }
                events
            elsif change.is_a?(Blink::Transaction)
                change.evaluate
            else
                raise "Transactions cannot handle objects of type %s" % child.class
            end
        }.flatten.each { |event|
            # this handles subscriptions on the components, rather than
            # on idividual objects
            self.component.subscribers?(event).each { |sub|
                sub.trigger(self)
            }
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # this should only be called by a Blink::Container object now
    # and it should only receive an array
    def initialize(tree)
        @tree = tree
        @toplevel = false

        @triggered = Hash.new(0)

        # of course, this won't work on the second run
        unless defined? @@failures
            @toplevel = true
            self.class.init
        end
        # change collection is in-band, and message generation is out-of-band
        # of course, exception raising is also out-of-band
        @changes = @tree.collect { |child|
            # these children are all Blink::Type instances
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
        @changes.each { |change|
            if change.is_a?(Blink::StateChange)
                next unless change.run
                #change.transaction = self
                begin
                    change.backward
                    #@@changed.push change.state.parent
                rescue => detail
                    Blink.error("%s rollback failed: %s" % [change,detail])
                    # at this point, we would normally do error handling
                    # but i haven't decided what to do for that yet
                    # so just record that a sync failed for a given object
                    #@@failures[change.state.parent] += 1
                    # this still could get hairy; what if file contents changed,
                    # but a chmod failed?  how would i handle that error? dern
                end
            elsif change.is_a?(Blink::Transaction)
                # yay, recursion
                change.rollback
            else
                raise "Transactions cannot handle objects of type %s" % child.class
            end
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def triggercount(sub)
        Blink.notice "Triggercount on %s is %s" % [sub,@triggered[sub]]
        return @triggered[sub]
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def triggered(sub)
        @triggered[sub] += 1
        Blink.notice "%s was triggered; count is %s" % [sub,@triggered[sub]]
    end
    #---------------------------------------------------------------
end
end
#---------------------------------------------------------------
