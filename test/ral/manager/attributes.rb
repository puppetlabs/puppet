#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2007-02-05.
#  Copyright (c) 2007. All rights reserved.

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'

class TestTypeAttributes < Test::Unit::TestCase
    include PuppetTest

    def mktype
        Puppet::Type.newtype(:faketype) {}
    end

    def teardown
        super
        if Puppet::Type.type(:faketype)
            Puppet::Type.rmtype(:faketype)
        end
    end

    def test_bracket_methods
        type = mktype

        # make a namevar
        type.newparam(:name) {}

        # make a property
        type.newproperty(:property) {}

        # and a param
        type.newparam(:param)

        inst = type.create(:name => "yay")

        # Make sure we can set each of them, including a metaparam
        [:param, :property, :noop].each do |param|
            assert_nothing_raised("Failed to set symbol") do
                inst[param] = true
            end

            assert_nothing_raised("Failed to set string") do
                inst[param.to_s] = true
            end

            if param == :property
                assert(inst.property(param), "did not get obj for %s" % param)
            end

            if param == :property
                assert_equal(true, inst.should(param),
                    "should value did not get set")
                inst.is = [:property, true]
            end

            # Now make sure we can get it back
            assert_equal(true, inst[param],
                "did not get correct value for %s from symbol" % param)
            assert_equal(true, inst[param.to_s],
                "did not get correct value for %s from string" % param)
        end
    end

    def test_properties
        type = mktype

        # make a namevar
        type.newparam(:name) {}

        # make a couple of properties
        props = [:one, :two, :three]
        props.each do |prop|
            type.newproperty(prop) {}
        end

        inst = type.create(:name => "yay")

        inst[:one] = "boo"
        one = inst.property(:one)
        assert(one, "did not get obj for one")
        assert_equal([one], inst.send(:properties), "got wrong properties")

        inst[:three] = "rah"
        three = inst.property(:three)
        assert(three, "did not get obj for three")
        assert_equal([one, three], inst.send(:properties), "got wrong properties")

        inst[:two] = "whee"
        two = inst.property(:two)
        assert(two, "did not get obj for two")
        assert_equal([one, two, three], inst.send(:properties), "got wrong properties")
    end

    def attr_check(type)
        @num ||= 0
        @num += 1
        name = "name%s" % @num
        inst = type.create(:name => name)
        [:meta, :param, :prop].each do |name|
            klass = type.attrclass(name)
            assert(klass, "did not get class for %s" % name)
            obj = yield inst, klass
            assert_instance_of(klass, obj, "did not get object back")
            assert_equal("value", inst.value(klass.name),
                "value was not correct from value method")
            assert_equal("value", obj.value, "value was not correct")
        end
    end

    def test_newattr
        type = mktype
        type.newparam(:name) {}

        # Make one of each param type
        {
            :meta => :newmetaparam, :param => :newparam, :prop => :newproperty
        }.each do |name, method|
            assert_nothing_raised("Could not make %s of type %s" % [name, method]) do
                type.send(method, name) {}
            end
        end

        # Now set each of them
        attr_check(type) do |inst, klass|
            inst.newattr(klass.name, :value => "value")
        end

        # Now try it passing the class in
        attr_check(type) do |inst, klass|
            inst.newattr(klass, :value => "value")
        end

        # Lastly, make sure we can create and then set, separately
        attr_check(type) do |inst, klass|
            obj = inst.newattr(klass.name)
            assert_nothing_raised("Could not set value after creation") do
                obj.value = "value"
            end

            # Make sure we can't create a new param object
            assert_raise(Puppet::Error,
                "Did not throw an error when replacing attr") do
                    inst.newattr(klass.name, :value => "yay")
            end
            obj
        end
    end

    def test_setdefaults
        type = mktype
        type.newparam(:name) {}
        
        # Make one of each param type
        {
            :meta2 => :newmetaparam, :param2 => :newparam, :prop2 => :newproperty
        }.each do |name, method|
            assert_nothing_raised("Could not make %s of type %s" % [name, method]) do
                type.send(method, name) do
                    defaultto "testing"
                end
            end
        end

        inst = type.create(:name => 'yay')
        assert_nothing_raised do
            inst.setdefaults
        end

        [:meta2, :param2, :prop2].each do |name|
            assert(inst.value(name), "did not get a value for %s" % name)
        end

        # Try a default of "false"
        type.newparam(:falsetest) do
            defaultto false
        end

        assert_nothing_raised do
            inst.setdefaults
        end
        assert_equal(false, inst[:falsetest], "false default was not set")
    end
end

# $Id$
