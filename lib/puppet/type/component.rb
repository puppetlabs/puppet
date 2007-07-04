
# the object allowing us to build complex structures
# this thing contains everything else, including itself

require 'puppet'
require 'puppet/type'
require 'puppet/transaction'
require 'puppet/pgraph'

Puppet::Type.newtype(:component) do
    include Enumerable
    attr_accessor :children

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
            return super
        end
    end

    # Recurse deeply through the tree, but only yield types, not properties.
    def delve(&block)
        self.each do |obj|
            if obj.is_a?(self.class)
                obj.delve(&block)
            end
        end
        block.call(self)
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

    def initvars
        super
        @children = []
    end

    def parent=(parent)
        if self.parentof?(parent)
            devfail "%s[%s] is already the parent of %s[%s]" %
                [self.class.name, self.title, parent.class.name, parent.title]
        end
        @parent = parent
    end

    # Add a hook for testing for recursion.
    def parentof?(child)
        if super(child)
            return true
        elsif @children.include?(child)
            debug "child is already in children array"
            return true
        else
            return false
        end
    end

    def push(*childs)
        unless defined? @children
            @children = []
        end
        childs.each { |child|
            # Make sure we don't have any loops here.
            if parentof?(child)
                devfail "Already the parent of %s[%s]" % [child.class.name, child.title]
            end
            unless child.is_a?(Puppet::Type)
                self.debug "Got object of type %s" % child.class
                self.devfail(
                    "Containers can only contain Puppet resources, not %s" %
                    child.class
                )
            end
            @children.push(child)
            child.parent = self
        }
    end
    
    # Component paths are special because they function as containers.
    def pathbuilder
        tmp = []
        if defined? @parent and @parent
            tmp += [@parent.pathbuilder, self.title]
        else
            # The top-level name is always main[top], so we don't bother with
            # that.
            if self.title == "main[top]"
                tmp << "" # This empty field results in "//" in the path
            else
                tmp << self.title
            end
        end
        
        tmp
    end

    # Remove an object.  The argument determines whether the object's
    # subscriptions get eliminated, too.
    def remove(rmdeps = true)
        # Our children remove themselves from our @children array (else the object
        # we called this on at the top would not be removed), so we duplicate the
        # array and iterate over that.  If we don't do this, only half of the
        # objects get removed.
        @children.dup.each { |child|
            child.remove(rmdeps)
        }

        @children.clear

        # Get rid of params and provider, too.
        super

        @parent = nil
    end

    # We have a different way of setting the title
    def title
        unless defined? @title
            if self[:type] == self[:name] # this is the case for classes
                @title = self[:type]
            elsif self[:name] =~ /\[.+\]/ # most components already have ref info in the name
                @title = self[:name]
            else # else, set it up
                @title = "%s[%s]" % [self[:type].capitalize, self[:name]]
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
                graph.add_edge!(obj, child)
                if child.is_a?(self.class)
                    delver.call(child)
                end
            end
        end
        
        delver.call(self)
        
        return graph
    end

    def to_s
        if self.title =~ /\[/
            return self.title
        else
            return "component(%s)" % self.title
        end
    end
end

# $Id$
