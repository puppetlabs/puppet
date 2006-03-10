if __FILE__ == $0
    $:.unshift '..'
    $:.unshift '../../lib'
    $puppetbase = "../.."
end

require 'puppet/type'
require 'puppettest'
require 'test/unit'

class TestState < Test::Unit::TestCase
	include TestPuppet

    def newinst(state)
        inst = nil
        assert_nothing_raised {
            return state.new(:parent => nil)
        }
    end
    
    def newstate(name = :fakestate)
        assert_nothing_raised {
            state = Class.new(Puppet::State) do
                @name = :fakeparam
            end
            state.initvars

            return state
        }
    end

    def test_newvalue
        state = newstate()

        assert_nothing_raised {
            state.newvalue(:one) do
                @is = 1
            end
        }

        assert_nothing_raised {
            state.newvalue("two") do
                @is = 2
            end
        }

        inst = newinst(state)

        assert_nothing_raised {
            inst.should = "one"
        }

        assert_equal(:one, inst.should)
        assert_nothing_raised { inst.set_one }
        assert_equal(1, inst.is)

        assert_nothing_raised {
            inst.should = :two
        }

        assert_equal(:two, inst.should)
        assert_nothing_raised { inst.set_two }
        assert_equal(2, inst.is)
    end

    def test_newstatevaluewithregexes
        state = newstate()

        assert_nothing_raised {
            state.newvalue(/^\w+$/) do
                @is = self.should.upcase
                return :regex_matched
            end
        }

        inst = newinst(state)

        assert_nothing_raised {
            inst.should = "yayness"
        }

        assert_equal("yayness", inst.should)

        assert_nothing_raised {
            inst.sync
        }

        assert_equal("yayness".upcase, inst.is)
    end
end

# $Id$
