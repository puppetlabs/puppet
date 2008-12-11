
require 'puppet'
require 'puppet/type'
require 'puppet/transaction'

Puppet::Type.newtype(:component) do
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

    # Initialize a new component
    def initialize(*args)
        super

        @reference = Puppet::Resource::Reference.new(:component, @title)

        if catalog and ! catalog.resource(@reference.to_s)
            catalog.alias(self, @reference.to_s)
        end
    end
    
    # Component paths are special because they function as containers.
    def pathbuilder
        if @reference.type == "Class"
            # 'main' is the top class, so we want to see '//' instead of
            # its name.
            if @reference.title == "main"
                myname = ""
            else
                myname = @reference.title
            end
        else
            myname = @reference.to_s
        end
        if p = self.parent
            return [p.pathbuilder, myname]
        else
            return [myname]
        end
    end

    def ref
        @reference.to_s
    end

    # We want our title to just be the whole reference, rather than @title.
    def title
        @reference.to_s
    end

    def refresh
        catalog.adjacent(self).each do |child|
            if child.respond_to?(:refresh)
                child.refresh
                child.log "triggering %s" % :refresh
            end
        end
    end

    def to_s
        @reference.to_s
    end
end
