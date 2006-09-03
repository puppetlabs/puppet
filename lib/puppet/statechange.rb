# the class responsible for actually doing any work

# enables no-op and logging/rollback

module Puppet
    # Handle all of the work around performing an actual change,
    # including calling 'sync' on the states and producing events.
	class StateChange
        attr_accessor :is, :should, :type, :path, :state, :transaction, :changed
        
        # The log file generated when this object was changed.
        attr_reader :report

        # Switch the goals of the state, thus running the change in reverse.
        def backward
            @state.should = @is
            @should = @is
            @is = @state.retrieve
            @state.is = @is

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

        def forward
            #@state.debug "moving change forward"

            unless defined? @transaction
                raise Puppet::Error,
                    "StateChange '%s' tried to be executed outside of transaction" %
                    self
            end

            return self.go
        end

        # Generate an appropriate event from the is/should values.
        def genevent
            tail = if @is == :absent
                       "created"
                   elsif @should == :absent
                       "deleted"
                   else
                       "changed"
                   end

            [state.parent.class.name.to_s, tail].join("_").intern
        end

        # Perform the actual change.  This method can go either forward or
        # backward, and produces an event.
        def go
            if @state.insync?
                @state.info "Already in sync"
                return nil
            end

            if @state.noop
                @state.log "is %s, should be %s (noop)" %
                    [state.is_to_s, state.should_to_s]
                #@state.debug "%s is noop" % @state
                return nil
            end

            #@state.info "Is: %s, Should: %s" %
            #    [@state.is.inspect, @state.should.inspect]

            # The transaction catches any exceptions here.
            if @state.method(:sync).arity == 0
                @state.warnstamp :syncwoutvalue, "sync() should accept a value"
                events = @state.sync
            else
                events = @state.sync(@should)
            end

            unless events.is_a? Array
                events = [events]
            end

            events = events.collect do |e|
                if e.nil?
                    genevent()
                else
                    if ! e.is_a?(Symbol)
                        @state.warning(
                            "State '%s' returned invalid event '%s'; resetting" %
                                [@state.class,e]
                        )
                        genevent()
                    else
                        e
                    end
                end
            end.reject { |e| e == :nochange }


            if events.empty?
                return nil
            end
            
            return events.collect { |event|
                # i should maybe include object type, but the event type
                # should basically point to that, right?
                    #:state => @state,
                    #:object => @state.parent,
                @report = @state.log(@state.change_to_s)
                Puppet::Event.new(
                    :event => event,
                    :change => self,
                    :transaction => @transaction,
                    :source => @state.parent,
                    :message => self.to_s
                )
            }
        end

        def initialize(state, is = nil)
            @state = state
            @path = [state.path,"change"].flatten

            if is
                @is = is
            else
                state.warning "did not pass 'is' to statechange"
                @is = state.is
            end

            if state.insync?
                raise Puppet::Error.new(
                    "Tried to create a change for in-sync state %s" % state.name
                )
            end
            @should = state.should

            @changed = false
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
