#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2007-02-05.
#  Copyright (c) 2007. All rights reserved.

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'

class TestTypeAttributes < Test::Unit::TestCase
    include PuppetTest

    def mktype
        type = Puppet::Type.newtype(:faketype) {}
        cleanup { Puppet::Type.rmtype(:faketype) }
        type
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

    def test_alias_parameter
        type = mktype
        type.newparam(:name) {}
        type.newparam(:one) {}
        type.newproperty(:two) {}
        
        aliases = {
            :three => :one,
            :four => :two
        }
        aliases.each do |new, old|
            assert_nothing_raised("Could not create alias parameter %s" % new) do
                type.set_attr_alias new => old
            end
        end

        aliases.each do |new, old|
            assert_equal(old, type.attr_alias(new), "did not return alias info for %s" %
                new)
        end

        assert_nil(type.attr_alias(:name), "got invalid alias info for name")

        inst = type.create(:name => "my name")
        assert(inst, "could not create instance")

        aliases.each do |new, old|
            val = "value %s" % new
            assert_nothing_raised do
                inst[new] = val
            end

            case old
            when :one: # param
                assert_equal(val, inst[new],
                    "Incorrect alias value for %s in []" % new)
            else
                assert_equal(val, inst.should(new),
                    "Incorrect alias value for %s in should" % new)
            end
            assert_equal(val, inst.value(new), "Incorrect alias value for %s" % new)
            assert_equal(val, inst.value(old), "Incorrect orig value for %s" % old)
        end
    end

    # Make sure eachattr is called in the parameter order.
    def test_eachattr
        type = mktype
        name = type.newparam(:name) {}
        one = type.newparam(:one) {}
        two = type.newproperty(:two) {}
        type.provide(:testing) {}
        provider = type.attrclass(:provider)
        should = [[name, :param], [provider, :param], [two, :property], [one, :param]]

        assert_nothing_raised do
            result = nil
            type.eachattr do |obj, name|
                result = [obj, name]
                shouldary = should.shift
                assert_equal(shouldary, result, "Did not get correct parameter")
                break if should.empty?
            end
        end
        assert(should.empty?, "Did not get all of the parameters.")
    end

    # Make sure newattr handles required features correctly.
    def test_newattr_and_required_features
        # Make a type with some features
        type = mktype
        type.feature :fone, "Something"
        type.feature :ftwo, "Something else"
        type.newparam(:name) {}

        # Make three properties: one with no requirements, one with one, and one with two
        none = type.newproperty(:none) {}
        one = type.newproperty(:one, :required_features => :fone) {}
        two = type.newproperty(:two, :required_features => [:fone, :ftwo]) {}

        # Now make similar providers
        nope = type.provide(:nope) {}
        maybe = type.provide(:maybe) { has_features :fone}
        yep = type.provide(:yep) { has_features :fone, :ftwo}

        attrs = [:none, :one, :two]

        # Now make sure that we get warnings and no properties in those cases where our providers do not support the features requested
        [nope, maybe, yep].each_with_index do |prov, i|
            resource = type.create(:provider => prov.name, :name => "test%s" % i, :none => "a", :one => "b", :two => "c")

            case prov.name
            when :nope:
                yes = [:none]
                no = [:one, :two]
            when :maybe:
                yes = [:none, :one]
                no = [:two]
            when :yep:
                yes = [:none, :one, :two]
                no = []
            end
            yes.each { |a| assert(resource.should(a), "Did not get value for %s in %s" % [a, prov.name]) }
            no.each do |a|
                assert_nil(resource.should(a), "Got value for unsupported %s in %s" % [a, prov.name])
                assert(@logs.find { |l| l.message =~ /not managing attribute #{a}/ and l.level == :info }, "No warning about failed %s" % a)
            end

            @logs.clear
        end
    end
end

# $Id$
