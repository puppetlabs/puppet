
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
        raise "Component#evaluate is deprecated"
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
    def initialize(*args)
        @children = []
        super

        # If the title isn't a full resource reference, assume
        # we're a class and make an alias for that.
        unless @title.to_s.include?("[")
            self.class.alias("class[%s]" % @title, self)
        end
    end

    def initvars
        super
        @children = []
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
    
    # Component paths are special because they function as containers.
    def pathbuilder
        tmp = []
        myname = ""
        if self.title =~ /^class\[(.+)\]$/i
            # 'main' is the top class, so we want to see '//' instead of
            # its name.
            unless $1 == "main"
                myname = $1
            end
        else
            myname = self.title
        end
        if p = self.parent
            return [p.pathbuilder, myname]
        else
            return [myname]
        end
    end

    def ref
        title
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
        configuration.adjacent(self).each do |child|
            if child.respond_to?(:refresh)
                child.refresh
                child.log "triggering %s" % :refresh
            end
        end
    end

    def to_s
        if self.title =~ /\[/
            return self.title
        else
            return "component(%s)" % self.title
        end
    end
end
