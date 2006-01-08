
# the object allowing us to build complex structures
# this thing contains everything else, including itself

require 'puppet'
require 'puppet/type'
require 'puppet/transaction'

module Puppet
    newtype(:component) do
        include Enumerable

        newparam(:name) do
            desc "The name of the component.  Generally optional."
            isnamevar
        end

        newparam(:type) do
            desc "The type that this component maps to.  Generally some kind of
                class from the language."

            defaultto "component"
        end

        # topo sort functions
        def self.sort(objects)
            list = []
            tmplist = {}

            objects.each { |obj|
                self.recurse(obj, tmplist, list)
            }

            return list.flatten
        end

        # FIXME this method assumes that dependencies themselves
        # are never components
        def self.recurse(obj, inlist, list)
            if inlist.include?(obj.object_id)
                return
            end
            inlist[obj.object_id] = true
            obj.eachdependency { |req|
                self.recurse(req, inlist, list)
            }

            if obj.is_a? self
                obj.each { |child|
                    self.recurse(child, inlist, list)
                }
            else
                list << obj
            end
        end

        # Remove a child from the component.
        def delete(child)
            if @children.include?(child)
                @children.delete(child)
                return true
            else
                return false
            end
        end

        # Return each child in turn.
        def each
            @children.each { |child| yield child }
        end
        
        # Return a flattened array containing all of the children
        # and all child components' children, sorted in order of dependencies.
        def flatten
            self.class.sort(@children).flatten
        end

        # Initialize a new component
        def initialize(args)
            @children = []
            super(args)
        end

        # flatten all children, sort them, and evaluate them in order
        # this is only called on one component over the whole system
        # this also won't work with scheduling, but eh
        def evaluate
            transaction = Puppet::Transaction.new(self.flatten)
            transaction.component = self
            return transaction
        end

        def name
            #return self[:name]
            unless defined? @name
                if self[:type] == self[:name]
                    @name = self[:type]
                else
                    @name = "%s[%s]" % [self[:type],self[:name]]
                end
            end
            return @name
        end

        def push(*ary)
            ary.each { |child|
                unless child.is_a?(Puppet::Element)
                    self.debug "Got object of type %s" % child.class
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
                    child.log "triggering %s" % :refresh
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

# $Id$
