#!/usr/bin/env ruby
#
#  Created by Luke A. Kanies on 2007-06-10.
#  Copyright (c) 2007. All rights reserved.

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'

class TestTypeInstances < Test::Unit::TestCase
    include PuppetTest

    def setup
        super
        @type = Puppet::Type.newtype(:instance_test) do
            newparam(:name) {}
            ensurable
        end
        cleanup { Puppet::Type.rmtype(:instance_test) }
    end

    # Make sure the instances class method works as expected.
    def test_instances
        # First make sure it throws an error when there are no providers
        assert_raise(Puppet::DevError, "Did not fail when no providers are present") do
            @type.instances
        end

        # Now add a couple of providers

        # The default
        @type.provide(:default) do
            defaultfor :operatingsystem => Facter.value(:operatingsystem)
            mk_resource_methods
            class << self
                attr_accessor :names
            end
            def self.instance(name)
                new(:name => name, :ensure => :present)
            end
            def self.instances
                @instances ||= names.collect { |name| instance(name) }
                @instances
            end

            @names = [:one]
        end

        # A provider with the same source
        @type.provide(:sub, :source => :default, :parent => :default) do
            @names = [:two]
        end

        # An unsuitable provider
        @type.provide(:nope, :parent => :default) do
            confine :exists => "/no/such/file"
            @names = [:three]
        end

        # Another suitable, non-default provider
        @type.provide(:yep, :parent => :default) do
            @names = [:four]
        end

        result = nil
        assert_nothing_raised("Could not get instance list") do
            result = @type.instances
        end

        assert_equal(:one, result[0].name, "Did not get default instances first")
        assert_equal(@type.provider(:default).instances[0], result[0].provider, "Provider instances were not maintained")

        resources = result.inject({}) { |hash, res| hash[res.name] = res; hash }
        assert(resources.include?(:four), "Did not get resources from other suitable providers")
        assert(! resources.include?(:three), "Got resources from unsuitable providers")

        # Now make sure the resources have an 'ensure' property to go with the value in the provider
        assert(resources[:one].send(:instance_variable_get, "@parameters").include?(:ensure), "Did not create ensure property")
    end
end

# $Id$
