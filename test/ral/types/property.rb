#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'

class TestProperty < Test::Unit::TestCase
	include PuppetTest

    def newinst(property, parent = nil)
        inst = nil
        unless parent
            parent = "fakeparent"
            parent.meta_def(:pathbuilder) do [self.to_s] end
            parent.meta_def(:provider) do nil end
            parent.meta_def(:fakeproperty) do '' end
        end
        assert_nothing_raised {
            newinst = property.new(:parent => parent)
            def newinst.retrieve(); return @fakeprovidervalue; end;
            return newinst
        }
    end
    
    def newproperty(name = :fakeproperty)
        property = Class.new(Puppet::Property) do
            @name = name
        end
        Object.const_set("FakeProperty", property)
        property.initvars
        cleanup do
            Object.send(:remove_const, "FakeProperty")
        end

        return property
    end

    def newmodel(name)
        # Create an object that responds to myproperty as an attr
        provklass = Class.new { attr_accessor name
            def pathbuilder
                ["provklass"]
            end
        }
        prov = provklass.new

        klass = Class.new { attr_accessor :provider, :path
            def pathbuilder
                ["instklass"]
            end
        }
        klassinst = klass.new
        klassinst.path = "instpath"
        klassinst.provider = prov

        return prov, klassinst
    end

    # Make sure we correctly look up names.
    def test_value_name
        property = newproperty()

        property.newvalue(:one)
        property.newvalue(/\d+/)

        name = nil
        ["one", :one].each do |value|
            assert_nothing_raised do
                name = property.value_name(value)
            end
            assert_equal(:one, name)
        end
        ["42"].each do |value|
            assert_nothing_raised do
                name = property.value_name(value)
            end
            assert_equal(/\d+/, name)
        end
        ["two", :three].each do |value|
            assert_nothing_raised do
                name = property.value_name(value)
            end
            assert_nil(name)
        end
    end

    # Test that we correctly look up options for values.
    def test_value_option
        property = newproperty()

        options = {
            :one => {:event => :yay, :call => :before},
            /\d+/ => {:event => :fun, :call => :instead}
        }
        property.newvalue(:one, options[:one])
        property.newvalue(/\d+/, options[/\d+/])

        options.each do |name, opts|
            opts.each do |param, value|
                assert_equal(value, property.value_option(name, param))
            end
        end
    end

    def test_newvalue
        property = newproperty()

        # These are bogus because they don't define events. :/
        assert_nothing_raised {
            property.newvalue(:one) do
                @fakeprovidervalue = 1
            end
        }

        assert_nothing_raised {
            property.newvalue("two") do
                @fakeprovidervalue = 2
            end
        }

        # Make sure we default to using the block instead
        assert_equal(:instead, property.value_option(:one, :call),
            ":call was not set to :instead when a block was provided")

        inst = newinst(property)

        assert_nothing_raised {
            inst.should = "one"
        }

        assert_equal(:one, inst.should)
        ret = nil
        assert_nothing_raised { inst.set_one }
        assert_equal(1, inst.retrieve)

        assert_nothing_raised {
            inst.should = :two
        }

        assert_equal(:two, inst.should)
        assert_nothing_raised { inst.set_two }
        assert_equal(2, inst.retrieve)
    end

    def test_newpropertyvaluewithregexes
        property = newproperty()

        assert_nothing_raised {
            property.newvalue(/^\w+$/) do
                return :regex_matched
            end
        }

        inst = newinst(property)

        assert_nothing_raised {
            inst.should = "yayness"
        }

        assert_equal("yayness", inst.should)

        assert_nothing_raised {
            inst.sync
        }

        assert_equal("yayness".upcase, inst.retrieve)
    end

    def test_newvalue_event_option
        property = newproperty()

        assert_nothing_raised do
            property.newvalue(:myvalue, :event => :fake_valued) do
            end
            property.newvalue(:other, :event => "fake_other") do
            end
        end
        inst = newinst(property)

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
        property = newproperty(:myproperty)

        assert_nothing_raised {
            property.newvalue(:value, :event => :matched_value)
        }
        assert_nothing_raised {
            property.newvalue(/^\d+$/, :event => :matched_number)
        }

        assert_equal(:none, property.value_option(:value, :call),
            ":call was not set to none when no block is provided")

        prov, klassinst = newmodel(:myproperty)

        inst = newinst(property, klassinst)

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
            assert_equal(value, prov.myproperty, "%s was not set right" % value)
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

        propertyklass = newproperty
 
        inst = nil
        assert_nothing_raised do
            inst = propertyklass.new(:parent => obj)
        end

        assert_nothing_raised do
            assert_equal(tags + [inst.name], inst.tags)
        end
    end

    def test_failure
        s = Struct.new(:line, :file, :path, :pathbuilder, :name)
        p = s.new(1, "yay", "rah", "struct", "name")

        myprovider = Class.new(Puppet::Provider)
  
        def p.provider; nil; end;
        myproperty = Class.new(Puppet::Property) do 
            @name = 'name'
        end
        myproperty.initvars

        myproperty.newvalue :mkfailure do
            raise "It's all broken"
        end
        property = myproperty.new(:parent => p)

        assert_raise(Puppet::Error) do
            property.set(:mkfailure)
        end
    end

    # Make sure 'set' behaves correctly WRT to call order.  This tests that the
    # :call value is handled correctly in all cases.
    def test_set
        property = newproperty(:myproperty)

        $setting = []

        newval = proc do |name, call|
            options = {}
            if call
                options[:call] = name
                block = proc { $setting << name }
            end
            assert_nothing_raised("Could not create %s value" % name) {
                if block
                    property.newvalue(name, options, &block)
                else
                    property.newvalue(name, options)
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
            property.newvalue(:implicit) do
                $setting << :implicit
            end
        end

        # Now create a provider
        prov, model = newmodel(:myproperty)
        inst = newinst(property, model)

        # Mark when we're called
        prov.meta_def(:myproperty=) do |value| $setting << :provider end

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
