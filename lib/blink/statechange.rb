#!/usr/local/bin/ruby -w

# $Id$

# the class responsible for actually doing any work

# enables no-op and logging/rollback

module Blink
	class StateChange
        attr_accessor :is, :should, :type, :path, :state, :transaction, :run

		#---------------------------------------------------------------
        def initialize(state)
            @state = state
            #@state.parent.newchange
            @path = state.fqpath
            @is = state.is
            @should = state.should

            @run = false
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def go
            if @state.noop
                #Blink.notice "%s is noop" % @state
                return nil
            end

            begin
                event = @state.sync
                @run = true
                
                # default to a simple event type
                if event.nil?
                    event = @state.parent.name.id2name + "_changed"
                elsif ! event.is_a?(Symbol)
                    Blink.notice "State '%s' returned invalid event '%s'; resetting to default" %
                        [@state.class,event]

                    event = @state.parent.name.id2name + "_changed"
                end

                # i should maybe include object type, but the event type
                # should basically point to that, right?
                return Blink::Event.new(
                    :event => event,
                    :object => @state.parent,
                    :transaction => @transaction,
                    :message => self.to_s
                )
            rescue => detail
                Blink.error "%s failed: %s" % [self.to_s,detail]
                # there should be a way to ask the state what type of event
                # it would have generated, but...
                return Blink::Event.new(
                    :event => @state.parent.name.id2name + "_failed",
                    :object => @state.parent,
                    :transaction => @transaction,
                    :message => "Failed: " + self.to_s
                )
            end
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def forward
            #Blink.notice "moving change forward"

            unless defined? @transaction
                raise "StateChange '%s' tried to be executed outside of transaction" %
                    self
            end

            return self.go
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def backward
            @state.should = @is
            @state.retrieve

            Blink.notice "Rolling %s backward" % self
            return self.go

            #raise "Moving statechanges backward is currently unsupported"
            #@type.change(@path,@should,@is)
        end
		#---------------------------------------------------------------
        
		#---------------------------------------------------------------
        def noop
            return @state.noop
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def to_s
            return "%s: %s => %s" % [@state,@is,@should]
        end
		#---------------------------------------------------------------
	end
end
