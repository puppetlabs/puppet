#!/usr/local/bin/ruby -w

# $Id$

# the object allowing us to build complex structures
# this thing contains everything else, including itself

require 'puppet'
require 'puppet/type'
require 'puppet/transaction'

module Puppet
	class Component < Puppet::Type
        include Enumerable

        @name = :component
        @namevar = :name

        @states = []
        @parameters = [:name,:type]

        def each
            @children.each { |child| yield child }
        end

        def initialize(args)
            @children = []
            super(args)
            Puppet.debug "Made component with name %s" % self.name
        end

        # now we decide whether a transaction is dumb, and just accepts
        # changes from the container, or whether it collects them itself
        # for now, because i've already got this implemented, let transactions
        # collect the changes themselves
        def evaluate
            transaction = Puppet::Transaction.new(@children)
            transaction.component = self
            return transaction
        end

        def push(*ary)
            ary.each { |child|
                unless child.is_a?(Puppet::Element)
                    Puppet.debug "Got object of type %s" % child.class
                    raise "Containers can only contain Puppet::Elements"
                end
                @children.push child
            }
        end

        def name
            return "%s[%s]" % [@parameters[:type],@parameters[:name]]
        end

        def refresh
            @children.collect { |child|
                if child.respond_to?(:refresh)
                    child.refresh
                end
            }
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
