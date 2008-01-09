class Puppet::Type
    # Specify a block for generating a list of objects to autorequire.  This
    # makes it so that you don't have to manually specify things that you clearly
    # require.
    def self.autorequire(name, &block)
        @autorequires ||= {}
        @autorequires[name] = block
    end

    # Yield each of those autorequires in turn, yo.
    def self.eachautorequire
        @autorequires ||= {}
        @autorequires.each { |type, block|
            yield(type, block)
        }
    end

    # Figure out of there are any objects we can automatically add as
    # dependencies.
    def autorequire(rel_catalog = nil)
        rel_catalog ||= catalog
        raise(Puppet::DevError, "You cannot add relationships without a catalog") unless rel_catalog

        reqs = []
        self.class.eachautorequire { |type, block|
            # Ignore any types we can't find, although that would be a bit odd.
            next unless typeobj = Puppet.type(type)

            # Retrieve the list of names from the block.
            next unless list = self.instance_eval(&block)
            unless list.is_a?(Array)
                list = [list]
            end

            # Collect the current prereqs
            list.each { |dep|
                obj = nil
                # Support them passing objects directly, to save some effort.
                unless dep.is_a? Puppet::Type
                    # Skip autorequires that we aren't managing
                    unless dep = rel_catalog.resource(type, dep)
                        next
                    end
                end
                
                reqs << Puppet::Relationship.new(dep, self)
            }
        }
        
        return reqs
    end

    # Build the dependencies associated with an individual object.
    def builddepends
        # Handle the requires
        self.class.relationship_params.collect do |klass|
            if param = @parameters[klass.name]
                param.to_edges
            end
        end.flatten.reject { |r| r.nil? }
    end
    
    # Does this resource have a relationship with the other?  We have to
    # check each object for both directions of relationship.
    def requires?(other)
        them = [other.class.name, other.title]
        me = [self.class.name, self.title]
        self.class.relationship_params.each do |param|
            case param.direction
            when :in: return true if v = self[param.name] and v.include?(them)
            when :out: return true if v = other[param.name] and v.include?(me)
            end
        end
        return false
    end

    # we've received an event
    # we only support local events right now, so we can pass actual
    # objects around, including the transaction object
    # the assumption here is that container objects will pass received
    # methods on to contained objects
    # i.e., we don't trigger our children, our refresh() method calls
    # refresh() on our children
    def trigger(event, source)
        trans = event.transaction
        if @callbacks.include?(source)
            [:ALL_EVENTS, event.event].each { |eventname|
                if method = @callbacks[source][eventname]
                    if trans.triggered?(self, method) > 0
                        next
                    end
                    if self.respond_to?(method)
                        self.send(method)
                    end

                    trans.triggered(self, method)
                end
            }
        end
    end
    
    # Unsubscribe from a given object, possibly with a specific event.
    def unsubscribe(object, event = nil)
        # First look through our own relationship params
        [:require, :subscribe].each do |param|
            if values = self[param]
                newvals = values.reject { |d|
                    d == [object.class.name, object.title]
                }
                if newvals.length != values.length
                    self.delete(param)
                    self[param] = newvals
                end
            end
        end
    end
end

