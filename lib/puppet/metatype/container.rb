class Puppet::Type

    # this is a retarded hack method to get around the difference between
    # component children and file children
    def self.depthfirst?
        if defined? @depthfirst
            return @depthfirst
        else
            return false
        end
    end
    
    def depthfirst?
        self.class.depthfirst?
    end

    # Add a hook for testing for recursion.
    def parentof?(child)
        if (self == child)
            debug "parent is equal to child"
            return true
        elsif defined? @parent and @parent.parentof?(child)
            debug "My parent is parent of child"
            return true
        else
            return false
        end
    end

    # Remove an object.  The argument determines whether the object's
    # subscriptions get eliminated, too.
    def remove(rmdeps = true)
        # This is hackish (mmm, cut and paste), but it works for now, and it's
        # better than warnings.
        @parameters.each do |name, obj|
            obj.remove
        end
        @parameters.clear

        @parent = nil

        # Remove the reference to the provider.
        if self.provider
            @provider.clear
            @provider = nil
        end
    end
end

