# the class responsible for actually doing any work

# enables no-op and logging/rollback

module Puppet
    # Handle all of the work around performing an actual change,
    # including calling 'sync' on the states and producing events.
	class StateChange
        attr_accessor :is, :should, :type, :path, :state, :transaction, :changed

        def initialize(state)
            @state = state
            @path = [state.path,"change"].flatten
            @is = state.is

            if state.insync?
                raise Puppet::Error.new(
                    "Tried to create a change for in-sync state %s" % state.name
                )
            end
            @should = state.should

            @changed = false
        end

        # Perform the actual change.  This method can go either forward or
        # backward, and produces an event.
        def go
            if @state.insync?
                @state.info "Already in sync"
                return nil
            end

            if @state.noop
                @state.log "is %s, should be %s" %
                    [state.is_to_s, state.should_to_s]
                #@state.debug "%s is noop" % @state
                return nil
            end

            #@state.info "Is: %s, Should: %s" %
            #    [@state.is.inspect, @state.should.inspect]

            # The transaction catches any exceptions here.
            events = @state.sync
            if events.nil?
                return nil
            end

            if events.is_a?(Array)
                if events.empty?
                    return nil
                end
            else
                events = [events]
            end
            
            return events.collect { |event|
                # default to a simple event type
                if ! event.is_a?(Symbol)
                    @state.warning("State '%s' returned invalid event '%s'; resetting to default" %
                        [@state.class,event])

                    event = @state.parent.class.name.id2name + "_changed"
                end

                # i should maybe include object type, but the event type
                # should basically point to that, right?
                    #:state => @state,
                    #:object => @state.parent,
                @state.log @state.change_to_s
                Puppet::Event.new(
                    :event => event,
                    :change => self,
                    :transaction => @transaction,
                    :source => @state.parent,
                    :message => self.to_s
                )
            }
        end

        def forward
            #@state.debug "moving change forward"

            unless defined? @transaction
                raise Puppet::Error,
                    "StateChange '%s' tried to be executed outside of transaction" %
                    self
            end

            return self.go
        end

        # Switch the goals of the state, thus running the change in reverse.
        def backward
            @state.should = @is
            @state.retrieve

            unless defined? @transaction
                raise Puppet::Error,
                    "StateChange '%s' tried to be executed outside of transaction" %
                    self
            end
            unless @state.insync?
                @state.info "Backing %s" % self
                return self.go
            else
                @state.debug "rollback is already in sync: %s vs. %s" %
                    [@state.is.inspect, @state.should.inspect]
                return nil
            end
        end
        
        def noop
            return @state.noop
        end

        def to_s
            return "change %s.%s(%s)" %
                [@transaction.object_id, self.object_id, @state.change_to_s]
            #return "change %s.%s" % [@transaction.object_id, self.object_id]
        end
	end
end

# $Id$
