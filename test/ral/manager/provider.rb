#!/usr/bin/env ruby

$:.unshift("../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'
require 'mocha'

class TestTypeProviders < Test::Unit::TestCase
	include PuppetTest

    # Make sure default providers behave correctly
    def test_defaultproviders
        # Make a fake type
        type = Puppet::Type.newtype(:defaultprovidertest) do
            newparam(:name) do end
        end

        cleanup { Puppet::Type.rmtype(:defaultprovidertest) }

        basic = type.provide(:basic) do
            defaultfor :operatingsystem => :somethingelse,
                :operatingsystemrelease => :yayness
        end

        assert_equal(basic, type.defaultprovider)
        type.defaultprovider = nil

        greater = type.provide(:greater) do
            defaultfor :operatingsystem => Facter.value("operatingsystem")
        end

        assert_equal(greater, type.defaultprovider)
    end

    # Make sure the provider is always the first parameter created.
    def test_provider_sorting
        type = Puppet::Type.newtype(:sorttest) do
            newparam(:name) {}
            ensurable
        end
        cleanup { Puppet::Type.rmtype(:sorttest) }

        should = [:name, :ensure]
        assert_equal(should, type.allattrs.reject { |p| ! should.include?(p) },
            "Got wrong order of parameters")

        type.provide(:yay) { }
        should = [:name, :provider, :ensure]
        assert_equal(should, type.allattrs.reject { |p| ! should.include?(p) },
            "Providify did not reorder parameters")
    end
end

# $Id$
