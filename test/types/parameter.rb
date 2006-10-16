#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet/type'
require 'puppettest'

class TestParameter < Test::Unit::TestCase
	include PuppetTest
    
    def newparam(name = :fakeparam)
        assert_nothing_raised {
            param = Class.new(Puppet::Parameter) do
                @name = :fakeparam
            end
            param.initvars

            return param
        }
    end

    def newinst(param)
        assert_nothing_raised {
            return param.new
        }
    end

    # Test the basic newvalue stuff.
    def test_newvalue
        param = newparam()

        # Try it with both symbols and strings.
        assert_nothing_raised {
            param.newvalues(:one, "two")
        }

        inst = newinst(param)

        assert_nothing_raised {
            inst.value = "one"
        }

        assert_equal(:one, inst.value)

        assert_nothing_raised {
            inst.value = :two
        }
        assert_equal(:two, inst.value)

        assert_raise(ArgumentError) {
            inst.value = :three
        }
        assert_equal(:two, inst.value)
    end

    # Test using regexes.
    def test_regexvalues
        param = newparam

        assert_nothing_raised {
            param.newvalues(/^\d+$/)
        }
        assert(param.match?("14"))
        assert(param.match?(14))

        inst = newinst(param)

        assert_nothing_raised {
            inst.value = 14
        }

        assert_nothing_raised {
            inst.value = "14"
        }

        assert_raise(ArgumentError) {
            inst.value = "a14"
        }
    end

    # Test using both.  Equality should beat matching.
    def test_regexesandnormals
        param = newparam

        assert_nothing_raised {
            param.newvalues(:one, /^\w+$/)
        }

        inst = newinst(param)

        assert_nothing_raised {
            inst.value = "one"
        }

        assert_equal(:one, inst.value, "Value used regex instead of equality")

        assert_nothing_raised {
            inst.value = "two"
        }
        assert_equal("two", inst.value, "Matched value didn't take")
    end
end

# $Id$
