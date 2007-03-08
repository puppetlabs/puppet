class Puppet::Type
    # This method is responsible for collecting property changes we always
    # descend into the children before we evaluate our current properties.
    # This returns any changes resulting from testing, thus 'collect' rather
    # than 'each'.
    def evaluate
        #Puppet.err "Evaluating %s" % self.path.join(":")
        unless defined? @evalcount
            self.err "No evalcount defined on '%s' of type '%s'" %
                [self.title,self.class]
            @evalcount = 0
        end
        @evalcount += 1

        if p = self.provider and p.respond_to?(:prefetch)
            p.prefetch
        end

        # this only operates on properties, not properties + children
        # it's important that we call retrieve() on the type instance,
        # not directly on the property, because it allows the type to override
        # the method, like pfile does
        self.retrieve

        changes = propertychanges().flatten

        # now record how many changes we've resulted in
        if changes.length > 0
            self.debug "%s change(s)" %
                [changes.length]
        end
        self.cache(:checked, Time.now)
        return changes.flatten
    end

    # Flush the provider, if it supports it.  This is called by the
    # transaction.
    def flush
        if self.provider and self.provider.respond_to?(:flush)
            self.provider.flush
        end
    end

    # if all contained objects are in sync, then we're in sync
    # FIXME I don't think this is used on the type instances any more,
    # it's really only used for testing
    def insync?
        insync = true

        if property = @parameters[:ensure]
            if property.insync? and property.should == :absent
                return true
            end
        end

        properties.each { |property|
            unless property.insync?
                property.debug("Not in sync: %s vs %s" %
                    [property.is.inspect, property.should.inspect])
                insync = false
            #else
            #    property.debug("In sync")
            end
        }

        #self.debug("%s sync status is %s" % [self,insync])
        return insync
    end

    # retrieve the current value of all contained properties
    def retrieve
        # it's important to use the method here, as it follows the order
        # in which they're defined in the object
        properties().each { |property|
            property.retrieve
        }
    end

    # Retrieve the changes associated with all of the properties.
    def propertychanges
        # If we are changing the existence of the object, then none of
        # the other properties matter.
        changes = []
        if @parameters.include?(:ensure) and ! @parameters[:ensure].insync?
#            self.info "ensuring %s from %s" %
#                [@parameters[:ensure].should, @parameters[:ensure].is]
            changes = [Puppet::PropertyChange.new(@parameters[:ensure])]
        # Else, if the 'ensure' property is correctly absent, then do
        # nothing
        elsif @parameters.include?(:ensure) and @parameters[:ensure].is == :absent
            #            self.info "Object is correctly absent"
            return []
        else
#            if @parameters.include?(:ensure)
#                self.info "ensure: Is: %s, Should: %s" %
#                    [@parameters[:ensure].is, @parameters[:ensure].should]
#            else
#                self.info "no ensure property"
#            end
            changes = properties().find_all { |property|
                ! property.insync?
            }.collect { |property|
                Puppet::PropertyChange.new(property)
            }
        end

        if Puppet[:debug] and changes.length > 0
            self.debug("Changing " + changes.collect { |ch|
                    ch.property.name
                }.join(",")
            )
        end

        changes
    end
end

# $Id$
