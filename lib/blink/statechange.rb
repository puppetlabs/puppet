#!/usr/local/bin/ruby -w

# $Id$

# the class responsible for actually doing any work

# enables no-op and logging/rollback

module Blink
	class StateChange
        attr_accessor :is, :should, :type, :path

		#---------------------------------------------------------------
        def initialize
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
	end
end
