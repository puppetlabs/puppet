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

    def newmodel(name)
        # Create an object that responds to mystate as an attr
        provklass = Class.new { attr_accessor name }
        prov = provklass.new

        klass = Class.new { attr_accessor :provider, :path }
        klassinst = klass.new
        klassinst.path = "instpath"
        klassinst.provider = prov

        return prov, klassinst
    end

    # Make sure we correctly look up names.
    def test_value_name
        state = newstate()

        state.newvalue(:one)
        state.newvalue(/\d+/)

        name = nil
        ["one", :one].each do |value|
            assert_nothing_raised do
                name = state.value_name(value)
            end
            assert_equal(:one, name)
        end
        ["42"].each do |value|
            assert_nothing_raised do
                name = state.value_name(value)
            end
            assert_equal(/\d+/, name)
        end
        ["two", :three].each do |value|
            assert_nothing_raised do
                name = state.value_name(value)
            end
            assert_nil(name)
        end
    end

    # Test that we correctly look up options for values.
    def test_value_option
        state = newstate()

        options = {
            :one => {:event => :yay, :call => :before},
            /\d+/ => {:event => :fun, :call => :instead}
        }
        state.newvalue(:one, options[:one])
        state.newvalue(/\d+/, options[/\d+/])

        options.each do |name, opts|
            opts.each do |param, value|
                assert_equal(value, state.value_option(name, param))
            end
        end
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

        # Make sure we default to using the block instead
        assert_equal(:instead, state.value_option(:one, :call),
            ":call was not set to :instead when a block was provided")

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

        assert_equal(:none, state.value_option(:value, :call),
            ":call was not set to none when no block is provided")

        prov, klassinst = newmodel(:mystate)

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

        mystate.newvalue :mkfailure do
            raise "It's all broken"
        end
        state = mystate.new(:parent => p)

        assert_raise(Puppet::Error) do
            state.set(:mkfailure)
        end
    end

    # Make sure 'set' behaves correctly WRT to call order.  This tests that the
    # :call value is handled correctly in all cases.
    def test_set
        state = newstate(:mystate)

        $setting = []

        newval = proc do |name, call|
            options = {}
            if call
                options[:call] = name
                block = proc { $setting << name }
            end
            assert_nothing_raised("Could not create %s value" % name) {
                if block
                    state.newvalue(name, options, &block)
                else
                    state.newvalue(name, options)
                end
            }
        end

        newval.call(:none, false)

        # Create a value with no block; it should default to :none
        newval.call(:before, true)

        # One with a block but after
        newval.call(:after, true)

        # One with an explicit instead
        newval.call(:instead, true)

        # And one with an implicit instead
        assert_nothing_raised do
            state.newvalue(:implicit) do
                $setting << :implicit
            end
        end

        # Now create a provider
        prov, model = newmodel(:mystate)
        inst = newinst(state, model)

        # Mark when we're called
        prov.meta_def(:mystate=) do |value| $setting << :provider end

        # Now run through the list and make sure everything is correct
        {:before => [:before, :provider],
            :after => [:provider, :after],
            :instead => [:instead],
            :none => [:provider],
            :implicit => [:implicit]
        }.each do |name, result|
            inst.set(name)

            assert_equal(result, $setting, "%s was not handled right" % name)
            $setting.clear
        end
    end
end

# $Id$
