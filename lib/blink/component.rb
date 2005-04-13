#!/usr/local/bin/ruby -w

# $Id$

# the object allowing us to build complex structures
# this thing contains everything else, including itself

require 'blink/interface'

module Blink
	class Component < Blink::Interface
        attr_accessor :name

        @objects = Hash.new(nil)

		#---------------------------------------------------------------
        # our components are effectively arrays, with a bit extra functionality
        def each
            @subobjects.each { |obj|
                yield obj
            }
        end
		#---------------------------------------------------------------

		#---------------------------------------------------------------
        def initialize(*args)
            args = Hash[*args]

            unless args.include?(:name)
                fail TypeError.new("Components must be provided a name")
            else
                self.name = args[:name]
            end

            Component[self.name] = self

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
        def to_s
            return self.name
        end
		#---------------------------------------------------------------
	end
end
