
require 'puppet'
require 'puppet/type'
require 'puppet/transaction'

Puppet::Type.newtype(:component) do
    include Enumerable

    newparam(:name) do
        desc "The name of the component.  Generally optional."
        isnamevar
    end

    # Override how parameters are handled so that we support the extra
    # parameters that are used with defined resource types.
    def [](param)
        return super if self.class.validattr?(param)
        @extra_parameters[param.to_sym]
    end

    # Override how parameters are handled so that we support the extra
    # parameters that are used with defined resource types.
    def []=(param, value)
        return super if self.class.validattr?(param)
        @extra_parameters[param.to_sym] = value
    end

    # Initialize a new component
    def initialize(*args)
        @extra_parameters = {}
        super

        if catalog and ! catalog.resource(ref)
            catalog.alias(self, ref)
        end
    end

    # Component paths are special because they function as containers.
    def pathbuilder
        if reference.type == "Class"
            # 'main' is the top class, so we want to see '//' instead of
            # its name.
            if reference.title == "main"
                myname = ""
            else
                myname = reference.title
            end
        else
            myname = reference.to_s
        end
        if p = self.parent
            return [p.pathbuilder, myname]
        else
            return [myname]
        end
    end

    def ref
        reference.to_s
    end

    # We want our title to just be the whole reference, rather than @title.
    def title
        ref
    end

    def title=(str)
        @reference = Puppet::Resource::Reference.new(str)
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
        reference.to_s
    end

    private

    attr_reader :reference
end
