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
    attr_accessor :toplevel

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

        @changes.each { |change|
            if change.is_a?(Blink::StateChange)
                change.transaction = self
                begin
                    change.forward
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
            elsif change.is_a?(Blink::Transaction)
                # yay, recursion
                change.evaluate
            else
                raise "Transactions cannot handle objects of type %s" % child.class
            end
        }

        if @toplevel # if we're the top transaction, perform the refreshes
            Blink::Event.process
            #notifies = @@changed.uniq.collect { |object|
            #    object.notify
            #}.flatten.uniq

            # now we have the entire list of objects to notify
        else
            # these are the objects that need to be refreshed
            #return @refresh.uniq
        end
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # this should only be called by a Blink::Container object now
    # and it should only receive an array
    def initialize(tree)
        @tree = tree
        @toplevel = false

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
end
end
#---------------------------------------------------------------
