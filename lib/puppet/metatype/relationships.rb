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
    def autorequire
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
                    unless dep = typeobj[dep]
                        next
                    end
                end
                
                debug "Autorequiring %s" % [dep.ref]
                reqs << Puppet::Relationship[dep, self]
            }
        }
        
        return reqs
    end

    # Build the dependencies associated with an individual object.  :in
    # relationships are specified by the event-receivers, and :out
    # relationships are specified by the event generator.  This
    # way 'source' and 'target' are consistent terms in both edges
    # and events -- that is, an event targets edges whose source matches
    # the event's source.  Note that the direction of the relationship
    # doesn't actually mean anything until you start using events --
    # the same information is present regardless.
    def builddepends
        # Handle the requires
        {:require => [:NONE, nil, :in],
            :subscribe => [:ALL_EVENTS, :refresh, :in],
            :notify => [:ALL_EVENTS, :refresh, :out],
            :before => [:NONE, nil, :out]}.collect do |type, args|
                if self[type]
                    handledepends(self[type], *args)
                end
            end.flatten.reject { |r| r.nil? }
    end

    def handledepends(requires, event, method, direction)
        # Requires are specified in the form of [type, name], so they're always
        # an array.  But we want them to be an array of arrays.
        unless requires[0].is_a?(Array)
            requires = [requires]
        end
        requires.collect { |rname|
            # we just have a name and a type, and we need to convert it
            # to an object...
            type = nil
            object = nil
            tname = rname[0]
            unless type = Puppet::Type.type(tname)
                self.fail "Could not find type %s" % tname.inspect
            end
            name = rname[1]
            unless object = type[name]
                self.fail "Could not retrieve object '%s' of type '%s'" %
                    [name,type]
            end
            self.debug("subscribes to %s" % [object])

            # Are we requiring them, or vice versa?  See the builddepends
            # method for further docs on this.
            if direction == :in
                source = object
                target = self
            else
                source = self
                target = object
            end

            # ok, both sides of the connection store some information
            # we store the method to call when a given subscription is 
            # triggered, but the source object decides whether 
            subargs = {
                :event => event
            }

            if method
                subargs[:callback] = method
            end
            rel = Puppet::Relationship.new(source, target, subargs)
        }
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
end

# $Id$
