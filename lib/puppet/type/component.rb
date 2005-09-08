#!/usr/local/bin/ruby -w

# $Id$

# the object allowing us to build complex structures
# this thing contains everything else, including itself

require 'puppet'
require 'puppet/type'
require 'puppet/transaction'

module Puppet
    class Type
	class Component < Puppet::Type
        include Enumerable

        @name = :component
        @namevar = :name

        @states = []
        @parameters = [:name,:type]

        # topo sort functions
        def self.sort(objects)
            list = []
            inlist = {}

            objects.each { |obj|
                self.recurse(obj, inlist, list)
            }

            return list
        end

        def self.recurse(obj, inlist, list)
            return if inlist.include?(obj.object_id)
            obj.eachdependency { |req|
                self.recurse(req, inlist, list)
            }
            
            list << obj
            inlist[obj.object_id] = true
        end

        def each
            @children.each { |child| yield child }
        end
        
        # this returns a sorted array, not a new component, but that suits me just fine
        def flatten
            self.class.sort(@children.collect { |child|
                if child.is_a?(self.class)
                    child.flatten
                else
                    child
                end
            }.flatten)
        end

        def initialize(args)
            @children = []

            # it makes sense to have a more reasonable default here than 'false'
            unless args.include?(:type) or args.include?("type")
                args[:type] = "component"
            end
            super(args)
            #Puppet.debug "Made component with name %s and type %s" %
            #    [self.name, self[:type]]
        end

        # the "old" way of doing things
        # just turn the container into a transaction
        def oldevaluate
            transaction = Puppet::Transaction.new(@children)
            transaction.component = self
            return transaction
        end

        # flatten all children, sort them, and evaluate them in order
        # this is only called on one component over the whole system
        # this also won't work with scheduling, but eh
        def evaluate
            # but what about dependencies?

            transaction = Puppet::Transaction.new(self.flatten)
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
                    Puppet.debug "Got object of type %s" % child.class
                    raise Puppet::DevError.new(
                        "Containers can only contain Puppet::Elements, not %s" %
                        child.class
                    )
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

        #def retrieve
        #    self.collect { |child|
        #        child.retrieve
        #    }
        #end

        def to_s
            return "component(%s)" % self.name
        end
	end
    end
end
