#!/usr/local/bin/ruby -w

# $Id$

# the class responsible for actually doing any work

# enables no-op and logging/rollback

module Blink
	class StateChange
        attr_accessor :is, :should, :type, :path, :state

		#---------------------------------------------------------------
        def initialize(state)
            @state = state
            @path = state.fqpath
            @is = state.is
            @should = state.should
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def forward
            Blink.notice "moving change forward"
            if @state.noop
                Blink.notice "%s is noop" % @state
                Blink.notice "change noop is %s" % @state.noop
            else
                Blink.notice "Calling sync on %s" % @state
                @state.sync
            end
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def backward
            raise "Moving statechanges backward is currently unsupported"
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
