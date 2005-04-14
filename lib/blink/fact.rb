#!/usr/local/bin/ruby -w

# $Id$

# an interface for registering and retrieving facts
# this is an abstract interface, and should just be used to interact
# with another library

# currently a very thin veneer on 'facter'

require 'facter'
require 'blink/types'

module Blink
	class Fact < Blink::Interface
        def Fact.[](name)
            Facter[name].value
        end

        # just pass the block to 'add'
        # the block has to do things like set the interpreter,
        # the code (which can be a ruby block), and maybe the
        # os and osrelease
        def Fact.add(name,&block)
            Facter[name].add(&block)
        end

        def Fact.name
            return :fact
        end

        def Fact.namevar
            return :name
        end

        Blink::Types.newtype(self)

        def initialize(hash)
            name = hash[:name]
            hash.delete(:name)
            Fact.add(name) { |fact|
                p fact
                hash.each { |key,value|
                    method = key + "="
                    #if key.is_a?(String)
                    #    key = key.intern
                    #end
                    fact.send(method,value)
                }
            }
        end
    end
end
