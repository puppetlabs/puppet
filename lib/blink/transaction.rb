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
    attr_accessor :collect  # do we collect the changes and perform them
                            # all at once?

    #---------------------------------------------------------------
    # for now, just store the changes for executing linearly
    # later, we might execute them as we receive them
    def change(change)
        @changes.push change
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def evaluate
        Blink.notice "evaluating %s changes" % @changes.length
        @changes.each { |change|
            msg = change.forward
        }
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def initialize(tree)
        @tree = tree
        @collect = true
        @changes = []
    end
    #---------------------------------------------------------------

    #---------------------------------------------------------------
    def run
        Blink.notice "running transaction"
        if @tree.is_a?(Array)
            @tree.each { |item|
                item.evaluate(self)
            }
        else
            @tree.evaluate(self)
        end
        Blink.notice "finished transaction"
        self.evaluate
    end
    #---------------------------------------------------------------
end
#---------------------------------------------------------------
