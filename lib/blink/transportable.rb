#!/usr/local/bin/ruby -w

# $Id$

# the interpreter
#
# this builds our virtual pinball machine, into which we'll place our host-specific
# information and out of which we'll receive our host-specific configuration

require 'blink'
require 'blink/parser/parser'


module Blink
    module Parser
        #------------------------------------------------------------
        class TransObject < Hash
            attr_accessor :type

            @@ohash = {}
            @@oarray = []

            def TransObject.clear
                @@oarray.clear
            end

            def TransObject.list
                return @@oarray
            end

            def initialize(name,type)
                self[:name] = name
                @type = type
                #if @@ohash.include?(name)
                #    raise "%s already exists" % name
                #else
                #    @@ohash[name] = self
                #    @@oarray.push(self)
                #end
                @@oarray.push self
            end

            def name
                return self[:name]
            end

            def to_s
                return "%s(%s) => %s" % [@type,self[:name],super]
            end
        end
        #------------------------------------------------------------

        #------------------------------------------------------------
        class TransSetting
            attr_accessor :type, :name, :args
        end
        #------------------------------------------------------------

        #------------------------------------------------------------
        # just a linear container for objects
        class TransBucket < Array
        end
        #------------------------------------------------------------
    end
end
