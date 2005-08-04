#!/usr/local/bin/ruby -w

# $Id$

# the class responsible for actually doing any work

# enables no-op and logging/rollback

module Puppet
	class StateChange
        attr_accessor :is, :should, :type, :path, :state, :transaction, :run

		#---------------------------------------------------------------
        def initialize(state)
            @state = state
            @path = [state.path,"change"].flatten
            @is = state.is

            if state.is == state.should
                raise Puppet::Error(
                    "Tried to create a change for in-sync state %s" % state.name
                )
            end
            @should = state.should

            @run = false
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def go
            if @state.noop
                #Puppet.debug "%s is noop" % @state
                return nil
            end

            if @state.is == @state.should
                raise Puppet::Error.new(
                    "Tried to change in-sync state %s" % state.name
                )
            end

            begin
                event = @state.sync
                @run = true
                
                # default to a simple event type
                if event.nil?
                    #event = @state.parent.class.name.id2name + "_changed"
                    # they didn't actually change anything
                    return
                elsif ! event.is_a?(Symbol)
                    Puppet.warning "State '%s' returned invalid event '%s'; resetting to default" %
                        [@state.class,event]

                    event = @state.parent.class.name.id2name + "_changed"
                end

                # i should maybe include object type, but the event type
                # should basically point to that, right?
                    #:state => @state,
                    #:object => @state.parent,
                Puppet.info self.to_s
                return Puppet::Event.new(
                    :event => event,
                    :change => self,
                    :transaction => @transaction,
                    :message => self.to_s
                )
            rescue => detail
                #Puppet.err "%s failed: %s" % [self.to_s,detail]
                raise
                # there should be a way to ask the state what type of event
                # it would have generated, but...
                pname = @state.parent.class.name.id2name
                #if pname.is_a?(Symbol)
                #    pname = pname.id2name
                #end
                    #:state => @state,
                    #:object => @state.parent,
                Puppet.info "Failed: " + self.to_s
                return Puppet::Event.new(
                    :event => pname + "_failed",
                    :change => self,
                    :transaction => @transaction,
                    :message => "Failed: " + self.to_s
                )
            end
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def forward
            #Puppet.debug "moving change forward"

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

            unless @state.insync?
                Puppet.notice "Rolling %s backward" % self
                return self.go
            end

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
            return "%s: %s changed %s to %s" %
                [@state.parent, @state.name, @is, @should]
        end
		#---------------------------------------------------------------
	end
end
