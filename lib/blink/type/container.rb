#!/usr/local/bin/ruby -w

# $Id$

# the object allowing us to build complex structures
# this thing contains everything else, including itself

require 'blink'
require 'blink/element'
require 'blink/transaction'
require 'blink/type'

module Blink
	class Container < Blink::Element
        @name = :container

        def initialize
            @children = []
        end

        # now we decide whether a transaction is dumb, and just accepts
        # changes from the container, or whether it collects them itself
        # for now, because i've already got this implemented, let transactions
        # collect the changes themselves
        def evaluate
            return transaction = Blink::Transaction.new(@children)
            #transaction.run
        end

        def push(*ary)
            ary.each { |child|
                unless child.is_a?(Blink::Element)
                    raise "Containers can only contain Blink::Elements"
                end
                @children.push child
            }
        end
	end
end
