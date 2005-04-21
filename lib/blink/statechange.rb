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
            @type.change(@path,@is,@should)
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def backward
            @type.change(@path,@should,@is)
        end
		#---------------------------------------------------------------
        
		#---------------------------------------------------------------
        def to_s
            return "%s: %s => %s" % [@path,@is,@should]
        end
		#---------------------------------------------------------------
	end
end
