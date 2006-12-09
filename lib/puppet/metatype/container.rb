class Puppet::Type
    attr_accessor :children

    # this is a retarded hack method to get around the difference between
    # component children and file children
    def self.depthfirst?
        if defined? @depthfirst
            return @depthfirst
        else
            return false
        end
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
        if (self == child)
            debug "parent is equal to child"
            return true
        elsif defined? @parent and @parent.parentof?(child)
            debug "My parent is parent of child"
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
            unless child.is_a?(Puppet::Element)
                self.debug "Got object of type %s" % child.class
                self.devfail(
                    "Containers can only contain Puppet::Elements, not %s" %
                    child.class
                )
            end
            @children.push(child)
            child.parent = self
        }
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

        # This is hackish (mmm, cut and paste), but it works for now, and it's
        # better than warnings.
        [@states, @parameters, @metaparams].each do |hash|
            hash.each do |name, obj|
                obj.remove
            end

            hash.clear
        end
        self.class.delete(self)

        @parent = nil

        # Remove the reference to the provider.
        if self.provider
            @provider.clear
            @provider = nil
        end
    end
end

# $Id$
