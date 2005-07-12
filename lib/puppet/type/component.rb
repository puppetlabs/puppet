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

        # yeah, this doc stuff is all pretty worthless right now
        @doc = %{
Component
---------
}

        @paramdoc = {
            :name => %{
},
            :type => %{
}
        }

        def each
            @children.each { |child| yield child }
        end

        def initialize(args)
            @children = []

            # it makes sense to have a more reasonable default here than 'false'
            unless args.include?(:type) or args.include?("type")
                args[:type] = "component"
            end
            super(args)
            debug "Made component with name %s and type %s" % [self.name, self[:type]]
        end

        # just turn the container into a transaction
        def evaluate
            transaction = Puppet::Transaction.new(@children)
            transaction.component = self
            return transaction
        end

        def name
            #return self[:name]
            return "%s[%s]" % [self[:type],self[:name]]
        end

        def push(*ary)
            ary.each { |child|
                unless child.is_a?(Puppet::Element)
                    debug "Got object of type %s" % child.class
                    raise "Containers can only contain Puppet::Elements"
                end
                @children.push child
                child.parent = self
            }
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
