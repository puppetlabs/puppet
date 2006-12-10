
# the object allowing us to build complex structures
# this thing contains everything else, including itself

require 'puppet'
require 'puppet/type'
require 'puppet/transaction'
require 'puppet/pgraph'

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

        # flatten all children, sort them, and evaluate them in order
        # this is only called on one component over the whole system
        # this also won't work with scheduling, but eh
        def evaluate
            self.finalize unless self.finalized?
            transaction = Puppet::Transaction.new(self)
            transaction.component = self
            return transaction
        end

        # Do all of the polishing off, mostly doing autorequires and making
        # dependencies.  This will get run once on the top-level component,
        # and it will do everything necessary.
        def finalize
            started = {}
            finished = {}
            
            # First do all of the finish work, which mostly involves
            self.delve do |object|
                # Make sure we don't get into loops
                if started.has_key?(object)
                    debug "Already finished %s" % object.title
                    next
                else
                    started[object] = true
                end
                unless finished.has_key?(object)
                    object.finish
                    finished[object] = true
                end
            end

            @finalized = true
        end

        def finalized?
            if defined? @finalized
                return @finalized
            else
                return false
            end
        end

        # Initialize a new component
        def initialize(args)
            @children = []
            super(args)
        end

        # We have a different way of setting the title
        def title
            unless defined? @title
                if self[:type] == self[:name] or self[:name] =~ /--\d+$/
                    @title = self[:type]
                else
                    @title = "%s[%s]" % [self[:type],self[:name]]
                end
            end
            return @title
        end

        def refresh
            @children.collect { |child|
                if child.respond_to?(:refresh)
                    child.refresh
                    child.log "triggering %s" % :refresh
                end
            }
        end
        
        # Convert to a graph object with all of the container info.
        def to_graph
            graph = Puppet::PGraph.new
            
            delver = proc do |obj|
                obj.each do |child|
                    if child.is_a?(Puppet::Type)
                        graph.add_edge!(obj, child)
                        delver.call(child)
                    end
                end
            end
            
            delver.call(self)
            
            return graph
        end

        def to_s
            return "component(%s)" % self.title
        end
	end
end

# $Id$
