#!/usr/bin/env ruby

$:.unshift("../lib").unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppet/type'
require 'puppettest'

class TestState < Test::Unit::TestCase
	include PuppetTest

    def newinst(state, parent = nil)
        inst = nil
        unless parent
            parent = "fakeparent"
            parent.meta_def(:path) do self.to_s end
        end
        assert_nothing_raised {
            return state.new(:parent => parent)
        }
    end
    
    def newstate(name = :fakestate)
        assert_nothing_raised {
            state = Class.new(Puppet::State) do
                @name = name
            end
            state.initvars

            return state
        }
    end

    def test_newvalue
        state = newstate()

        # These are bogus because they don't define events. :/
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
        ret = nil
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

    def test_newvalue_event_option
        state = newstate()

        assert_nothing_raised do
            state.newvalue(:myvalue, :event => :fake_valued) do
                @is = :valued
            end
            state.newvalue(:other, :event => "fake_other") do
                @is = :valued
            end
        end
        inst = newinst(state)

        assert_nothing_raised {
            inst.should = :myvalue
        }

        ret = nil
        assert_nothing_raised {
            ret = inst.sync
        }

        assert_equal(:fake_valued, ret,
                     "Event did not get returned correctly")

        assert_nothing_raised {
            inst.should = :other
        }

        assert_nothing_raised {
            ret = inst.sync
        }

        assert_equal(:fake_other, ret,
                     "Event did not get returned correctly")
    end

    # We want to support values with no blocks, either regexes or strings.
    # If there's no block provided, then we should call the provider mechanism
    # like we would normally.
    def test_newvalue_with_no_block
        state = newstate(:mystate)

        assert_nothing_raised {
            state.newvalue(:value, :event => :matched_value)
        }
        assert_nothing_raised {
            state.newvalue(/^\d+$/, :event => :matched_number)
        }

        # Create an object that responds to mystate as an attr
        provklass = Class.new { attr_accessor :mystate }
        prov = provklass.new

        klass = Class.new { attr_accessor :provider, :path }
        klassinst = klass.new
        klassinst.path = "instpath"
        klassinst.provider = prov

        inst = newinst(state, klassinst)

        # Now make sure we can set the values, they get validated as normal,
        # and they set the values on the parent rathe than trying to call
        # a method
        {:value => :matched_value, "27" => :matched_number}.each do |value, event|
            assert_nothing_raised do
                inst.should = value
            end
            ret = nil
            assert_nothing_raised do
                ret = inst.sync
            end
            assert_equal(event, ret, "Did not return correct event for %s" % value)
            assert_equal(value, prov.mystate, "%s was not set right" % value)
        end

        # And make sure we still fail validations
        assert_raise(ArgumentError) do
            inst.should = "invalid"
        end
    end

    def test_tags
        obj = "yay"
        metaobj = class << obj; self; end

        metaobj.send(:attr_accessor, :tags)

        tags = [:some, :tags, :for, :testing]
        obj.tags = tags

        stateklass = newstate
 
        inst = nil
        assert_nothing_raised do
            inst = stateklass.new(:parent => obj)
        end

        assert_nothing_raised do
            assert_equal(tags + [inst.name], inst.tags)
        end
    end

    def test_failure
        s = Struct.new(:line, :file, :path)
        p = s.new(1, "yay", "rah")
        mystate = Class.new(Puppet::State)
        mystate.initvars
        state = mystate.new(:parent => p)

        class << state
            def set_mkfailure
                raise "It's all broken"
            end
        end

        state.should = :mkfailure

        assert_raise(Puppet::Error) do
            state.set
        end
    end
end

# $Id$
