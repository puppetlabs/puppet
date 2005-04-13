#!/usr/local/bin/ruby -w

# $Id$

require 'blink'
require 'blink/fact'

module Blink
    #---------------------------------------------------------------
    # this class will provide something like a 'select' statement, but it will
    # return a value
    # it will be used something like this:
    # value = Selector.new(
    #  proc { test() } => value,
    #  proc { test2() } => value2,
    # )

    # each test gets evaluated in turn; the first one to return true has its
    # value returned as the value of the statement
    # this will be used to provide abstraction in objects, but it's currently
    # unused

    class Selector < Array
        attr_accessor :default

        def add(value,&block)
            option = Option.new(value,&block)
            @ohash[value] = option
            @oarray.push(option)
        end

        def evaluate
            @oarray.each { |option|
                if option.true?
                    return option.value
                end
            }
            return nil
        end

        # we have to support providing different values based on
        # different criteria, e.g., default is X, SunOS gets Y, and
        # host Yayness gets Z.
        # thus, no invariant
        def initialize
            @oarray = []
            @ohash = {}

            if block_given?
                yield self
            end
        end

        def to_s
            return self.evaluate()
        end

        class Option
            attr_accessor :value, :test, :invariant

            def initialize(value,&block)
                @value = value
                @test = block
            end

            def to_s
                if self.evaluate
                    return value
                end
            end

            def true?
                unless @test.is_a?(Proc)
                    raise "Cannot yet evaluate non-code tests"
                end

                return @test.call()
            end
        end
    #---------------------------------------------------------------
    end
end
