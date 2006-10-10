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
                if dep.is_a? Puppet::Type
                    type = dep.class.name
                    obj = dep

                    # Now change our dependency to just the string, instead of
                    # the object itself.
                    dep = dep.title
                else
                    # Skip autorequires that we aren't managing
                    unless obj = typeobj[dep]
                        next
                    end
                end

                # Skip autorequires that we already require
                next if self.requires?(obj)

                debug "Autorequiring %s %s" % [obj.class.name, obj.title]
                self[:require] = [type, dep]
            }

            #self.info reqs.inspect
            #self[:require] = reqs
        }
    end

    # Build the dependencies associated with an individual object.
    def builddepends
        # Handle the requires
        if self[:require]
            self.handledepends(self[:require], :NONE, nil, true)
        end

        # And the subscriptions
        if self[:subscribe]
            self.handledepends(self[:subscribe], :ALL_EVENTS, :refresh, true)
        end

        if self[:notify]
            self.handledepends(self[:notify], :ALL_EVENTS, :refresh, false)
        end

        if self[:before]
            self.handledepends(self[:before], :NONE, nil, false)
        end
    end

    # return all objects that we depend on
    def eachdependency
        Puppet::Event::Subscription.dependencies(self).each { |dep|
            yield dep.source
        }
    end

    # return all objects subscribed to the current object
    def eachsubscriber
        Puppet::Event::Subscription.subscribers(self).each { |sub|
            yield sub.target
        }
    end

    def handledepends(requires, event, method, up)
        # Requires are specified in the form of [type, name], so they're always
        # an array.  But we want them to be an array of arrays.
        unless requires[0].is_a?(Array)
            requires = [requires]
        end
        requires.each { |rname|
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

            # Are we requiring them, or vice versa?
            source = target = nil
            if up
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
                :event => event,
                :source => source,
                :target => target
            }

            if method and target.respond_to?(method)
                subargs[:callback] = method
            end
            Puppet::Event::Subscription.new(subargs)
        }
    end

    def requires?(object)
        req = false
        self.eachdependency { |dep|
            if dep == object
                req = true
                break
            end
        }

        return req
    end

    def subscribe(hash)
        hash[:source] = self
        Puppet::Event::Subscription.new(hash)

        # add to the correct area
        #@subscriptions.push sub
    end

    def subscribesto?(object)
        sub = false
        self.eachsubscriber { |o|
            if o == object
                sub = true
                break
            end
        }

        return sub
    end

    # Unsubscribe from a given object, possibly with a specific event.
    def unsubscribe(object, event = nil)
        Puppet::Event::Subscription.dependencies(self).find_all { |sub|
            if event
                sub.match?(event)
            else
                sub.source == object
            end
        }.each { |sub|
            sub.delete
        }
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
