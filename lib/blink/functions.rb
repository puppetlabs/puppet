#!/usr/local/bin/ruby -w

# $Id$

require 'blink'
require 'blink/fact'

module Blink
    class Function
        @@functions = Hash.new(nil)

        #---------------------------------------------------------------
        def [](name)
            return @@functions[name]
        end
        #---------------------------------------------------------------

        #---------------------------------------------------------------
        def call(*args)
            @code.call(*args)
        end
        #---------------------------------------------------------------

        #---------------------------------------------------------------
        # we want a 'proc' item instead of a block, so that we can return
        # from it
        def initialize(name,code)
            @name = name
            @code = code

            @@functions[name] = self
        end
        #---------------------------------------------------------------
    end

    Function.new("retrieve", proc { |fact|
        require 'blink/fact'

        return Fact[fact]
    })
end
