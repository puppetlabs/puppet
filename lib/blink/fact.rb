#!/usr/local/bin/ruby -w

# $Id$

# an interface for registering and retrieving facts
# this is an abstract interface, and should just be used to interact
# with another library

# currently a very thin veneer on 'facter'

require 'facter'

module Blink
	class Fact
        # just pass the block to 'add'
        # the block has to do things like set the interpreter,
        # the code (which can be a ruby block), and maybe the
        # os and osrelease
        def Fact.add(name,&block)
            Facter[name].add(&block)
        end

        def Fact.[](name)
            Facter[name].value
        end
    end
end
