#!/usr/local/bin/ruby -w

# $Id$

# the object allowing us to build complex structures
# this thing contains everything else, including itself

require 'blink'
require 'blink/type'
require 'blink/transaction'

module Blink
	class Component < Blink::Type
        include Enumerable

        @name = :container
        @namevar = :name

        @states = []
        @parameters = [:name,:type]

        def each
            @children.each { |child| yield child }
        end

        def initialize(args)
            @children = []
            super(args)
            Blink.verbose "Made component with name %s" % self.name
        end

        # now we decide whether a transaction is dumb, and just accepts
        # changes from the container, or whether it collects them itself
        # for now, because i've already got this implemented, let transactions
        # collect the changes themselves
        def evaluate
            transaction = Blink::Transaction.new(@children)
            transaction.component = self
            return transaction
        end

        def push(*ary)
            ary.each { |child|
                unless child.is_a?(Blink::Element)
                    Blink.notice "Got object of type %s" % child.class
                    raise "Containers can only contain Blink::Elements"
                end
                @children.push child
            }
        end

        def name
            return "%s[%s]" % [@parameters[:type],@parameters[:name]]
        end

        def retrieve
            self.collect { |child|
                child.retrieve
            }
        end

        def to_s
            return "component(%s)" % self.name
        end
	end
end
