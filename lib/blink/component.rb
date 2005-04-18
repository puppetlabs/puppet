#!/usr/local/bin/ruby -w

# $Id$

# the object allowing us to build complex structures
# this thing contains everything else, including itself

require 'blink/type'

module Blink
	class Component < Blink::Type
        attr_accessor :name

        @name = :component
        @namevar = :name
        @params = [
            :name
        ]

		#---------------------------------------------------------------
        def [](object)
            @subobjects[object]
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        # our components are effectively arrays, with a bit extra functionality
        def each
            @subobjects.each { |obj|
                yield obj
            }
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def initialize(hash)
            #super(hash)
            begin
                @name = hash[:name]
            rescue
                fail TypeError.new("Components must be provided a name")
            end

            unless @name
                fail TypeError.new("Components must be provided a name")
            end

            self.class[self.name] = self

            @subobjects = []
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def push(*objs)
            objs.each { |obj|
                @subobjects.push(obj)
            }
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        #def to_s
        #    return self.name
        #end
		#---------------------------------------------------------------
	end
end
