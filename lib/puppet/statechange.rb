# the class responsible for actually doing any work

# enables no-op and logging/rollback

module Puppet
    # Handle all of the work around performing an actual change,
    # including calling 'sync' on the states and producing events.
	class StateChange
        attr_accessor :is, :should, :type, :path, :state, :transaction, :changed, :proxy
        
        # The log file generated when this object was changed.
        attr_reader :report
        
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
        
        def changed?
            self.changed
        end

        def initialize(state)
            @state = state
            @path = [state.path,"change"].flatten
            @is = state.is

            @should = state.should

            @changed = false
        end

        # Perform the actual change.  This method can go either forward or
        # backward, and produces an event.
        def go
            return nil if skip?

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
                unless event.is_a?(Symbol)
                    @state.warning("State '%s' returned invalid event '%s'; resetting to default" %
                        [@state.class,event])

                    event = @state.parent.class.name.id2name + "_changed"
                end
                
                @report = @state.log(@state.change_to_s)
                Puppet::Event.new(
                    :event => event,
                    :transaction => @transaction,
                    :source => self.source
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
        
        def noop
            return @state.noop
        end
        
        def skip?
            if @state.insync?
                @state.info "Already in sync"
                return true
            end

            if @state.noop
                @state.log "is %s, should be %s (noop)" %
                    [state.is_to_s, state.should_to_s]
                #@state.debug "%s is noop" % @state
                return true
            end
            return false
        end
        
        def source
            self.proxy || @state.parent
        end

        def to_s
            return "change %s.%s(%s)" %
                [@transaction.object_id, self.object_id, @state.change_to_s]
            #return "change %s.%s" % [@transaction.object_id, self.object_id]
        end
	end
end

# $Id$
