class Puppet::Type
    attr_writer :implicit

    def self.implicitcreate(hash)
        unless hash.include?(:implicit)
            hash[:implicit] = true
        end
        if obj = self.create(hash)
            obj.implicit = true

            return obj
        else
            return nil
        end
    end

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

    # Merge new information with an existing object, checking for conflicts
    # and such.  This allows for two specifications of the same object and
    # the same values, but it's pretty limited right now.  The result of merging
    # properties is very different from the result of merging parameters or
    # metaparams.  This is currently unused.
    def merge(hash)
        hash.each { |param, value|
            if param.is_a?(String)
                param = param.intern
            end
            
            # Of course names are the same, duh.
            next if param == :name or param == self.class.namevar

            unless value.is_a?(Array)
                value = [value]
            end

            if @parameters.include?(param) and oldvals = @parameters[param].shouldorig
                unless oldvals.is_a?(Array)
                    oldvals = [oldvals]
                end
                # If the values are exactly the same, order and everything,
                # then it's okay.
                if oldvals == value
                    return true
                end
                # take the intersection
                newvals = oldvals & value
                if newvals.empty?
                    self.fail "No common values for %s on %s(%s)" %
                        [param, self.class.name, self.title]
                elsif newvals.length > 1
                    self.fail "Too many values for %s on %s(%s)" %
                        [param, self.class.name, self.title]
                else
                    self.debug "Reduced old values %s and new values %s to %s" %
                        [oldvals.inspect, value.inspect, newvals.inspect]
                    @parameters[param].should = newvals
                    #self.should = newvals
                    return true
                end
            else
                self[param] = value
            end
        }

        # Set the defaults again, just in case.
        self.setdefaults
    end
end

# $Id$
