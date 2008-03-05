class Puppet::Type
    attr_writer :implicit

    # Is this type's name isomorphic with the object?  That is, if the
    # name conflicts, does it necessarily mean that the objects conflict?
    # Defaults to true.
    def self.isomorphic?
        if defined? @isomorphic
            return @isomorphic
        else
            return true
        end
    end

    def implicit?
        if defined? @implicit and @implicit
            return true
        else
            return false
        end
    end

    def isomorphic?
        self.class.isomorphic?
    end

    # is the instance a managed instance?  A 'yes' here means that
    # the instance was created from the language, vs. being created
    # in order resolve other questions, such as finding a package
    # in a list
    def managed?
        # Once an object is managed, it always stays managed; but an object
        # that is listed as unmanaged might become managed later in the process,
        # so we have to check that every time
        if defined? @managed and @managed
            return @managed
        else
            @managed = false
            properties.each { |property|
                s = property.should
                if s and ! property.class.unmanaged
                    @managed = true
                    break
                end
            }
            return @managed
        end
    end
end
