class Puppet::Type
    # retrieve the current value of all contained states
    def retrieve
        # it's important to use the method here, as it follows the order
        # in which they're defined in the object
        states().each { |state|
            state.retrieve
        }
    end

    # Retrieve the changes associated with all of the states.
    def statechanges
        # If we are changing the existence of the object, then none of
        # the other states matter.
        changes = []
        if @states.include?(:ensure) and ! @states[:ensure].insync?
            #self.info "ensuring %s from %s" %
            #    [@states[:ensure].should, @states[:ensure].is]
            changes = [Puppet::StateChange.new(@states[:ensure])]
        # Else, if the 'ensure' state is correctly absent, then do
        # nothing
        elsif @states.include?(:ensure) and @states[:ensure].is == :absent
            #self.info "Object is correctly absent"
            return []
        else
            #if @states.include?(:ensure)
            #    self.info "ensure: Is: %s, Should: %s" %
            #        [@states[:ensure].is, @states[:ensure].should]
            #else
            #    self.info "no ensure state"
            #end
            changes = states().find_all { |state|
                ! state.insync?
            }.collect { |state|
                Puppet::StateChange.new(state)
            }
        end

        if Puppet[:debug] and changes.length > 0
            self.debug("Changing " + changes.collect { |ch|
                    ch.state.name
                }.join(",")
            )
        end

        changes
    end

    # this method is responsible for collecting state changes
    # we always descend into the children before we evaluate our current
    # states
    # this returns any changes resulting from testing, thus 'collect'
    # rather than 'each'
    def evaluate
        #Puppet.err "Evaluating %s" % self.path.join(":")
        unless defined? @evalcount
            self.err "No evalcount defined on '%s' of type '%s'" %
                [self.title,self.class]
            @evalcount = 0
        end
        @evalcount += 1

        changes = []

        # this only operates on states, not states + children
        # it's important that we call retrieve() on the type instance,
        # not directly on the state, because it allows the type to override
        # the method, like pfile does
        self.retrieve

        # states() is a private method, returning an ordered list
        unless self.class.depthfirst?
            changes += statechanges()
        end

        changes << @children.collect { |child|
            ch = child.evaluate
            child.cache(:checked, Time.now)
            ch
        }

        if self.class.depthfirst?
            changes += statechanges()
        end

        changes.flatten!

        # now record how many changes we've resulted in
        if changes.length > 0
            self.debug "%s change(s)" %
                [changes.length]
        end
        self.cache(:checked, Time.now)
        return changes.flatten
    end

    # if all contained objects are in sync, then we're in sync
    # FIXME I don't think this is used on the type instances any more,
    # it's really only used for testing
    def insync?
        insync = true

        if state = @states[:ensure]
            if state.insync? and state.should == :absent
                return true
            end
        end

        states.each { |state|
            unless state.insync?
                state.debug("Not in sync: %s vs %s" %
                    [state.is.inspect, state.should.inspect])
                insync = false
            #else
            #    state.debug("In sync")
            end
        }

        #self.debug("%s sync status is %s" % [self,insync])
        return insync
    end
end

# $Id$
