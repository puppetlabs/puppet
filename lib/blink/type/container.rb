#!/usr/local/bin/ruby -w

# $Id$

# the object allowing us to build complex structures
# this thing contains everything else, including itself

require 'blink/type'

module Blink
	class Component < Blink::Type
        @name = :component
        @namevar = :name

        @parameters = [
            :name
        ]

        @states = []
	end
end
