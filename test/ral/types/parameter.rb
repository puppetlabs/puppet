#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

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
            return param.new(:resource => "yay")
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

    def test_shadowing
        type = Puppet::Type.newtype(:faketype) { newparam(:name) {} }

        cleanup { Puppet::Type.rmtype(:faketype) }

        param = nil
        assert_nothing_raised do
            param = type.newproperty(:alias)
        end

        assert(param, "did not create param")

        inst = type.create(:name => "test")

        config = mk_catalog
        inst.catalog = config

        assert_nothing_raised("Could not create shadowed param") {
            inst[:alias] = "foo"
        }

        # Get the parameter hash from the instance so we can check the shadow
        params = inst.instance_variable_get("@parameters")
        obj = params[:alias]
        assert(obj, "did not get alias parameter")
        assert(obj.shadow, "shadow was not created for alias param")

        assert(obj.is_a?(Puppet::Property),
            "alias instance is not a property")
        assert_instance_of(param, obj, "alias is an instance of the wrong class")

        # Make sure the alias got created
        assert(config.resource(type.name, "foo"), "Did not retrieve object by its alias")
        
        # Now try it during initialization
        other = nil
        assert_nothing_raised("Could not create instance with shadow") do
            other = type.create(:name => "rah", :alias => "one", :catalog => config)
        end
        params = other.instance_variable_get("@parameters")
        obj = params[:alias]
        assert(obj, "did not get alias parameter")
        assert(obj.shadow, "shadow was not created for alias param")

        assert_instance_of(param, obj, "alias is an instance of the wrong class")
        assert(obj.is_a?(Puppet::Property),
            "alias instance is not a property")

        # Now change the alias and make sure it works out well
        assert_nothing_raised("Could not modify shadowed alias") do
            other[:alias] = "two"
        end

        obj = params[:alias]
        assert(obj, "did not get alias parameter")
        assert_instance_of(param, obj, "alias is now an instance of the wrong class")
        assert(obj.is_a?(Puppet::Property),
            "alias instance is now not a property")
    end

    # Make sure properties can correctly require features and behave appropriately when
    # those features are missing.
    def test_requires_features
        param = newparam(:feature_tests)

        assert_nothing_raised("could not add feature requirements to property") do
            param.required_features = "testing"
        end

        assert_equal([:testing], param.required_features, "required features value was not arrayfied and interned")
    end
end

