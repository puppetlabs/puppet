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
class Blink::Transaction
    #---------------------------------------------------------------
    # for now, just store the changes for executing linearly
    # later, we might execute them as we receive them
    def change(change)
        @children.push change
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def evaluate
        Blink.notice "executing %s changes" % @children.length

        @children.each { |change|
            if change.is_a?(Blink::StateChange)
                begin
                    change.forward
                rescue => detail
                    Blink.error("%s failed: %s" % [change,detail])
                    # at this point, we would normally roll back the transaction
                    # but, um, i don't know how to do that yet
                end
            elsif change.is_a?(Blink::Transaction)
                change.evaluate
            else
                raise "Transactions cannot handle objects of type %s" % child.class
            end
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    # this should only be called by a Blink::Container object now
    # and it should only receive an array
    def initialize(tree)
        @tree = tree

        # change collection is in-band, and message generation is out-of-band
        # of course, exception raising is also out-of-band
        @children = @tree.collect { |child|
            # not all of the children will return a change
            child.evaluate
        }.flatten.reject { |child|
            child.nil? # remove empties
        }
    end
    #---------------------------------------------------------------
end
#---------------------------------------------------------------
