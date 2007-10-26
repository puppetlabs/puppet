#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../lib/puppettest'

require 'puppettest'
require 'mocha'

class TestInterfaceType < PuppetTest::TestCase
    confine "Could not find suitable interface provider" => Puppet::Type.type(:interface).suitableprovider.length > 0

    def setup
        super
        @type = Puppet::Type.type(:interface)
    end

    def test_prefetch
        interface = @type.create(:name => "127.0.0.1", :interface => "lo0", :check => :all)

        @type.suitableprovider.each do |provider|
            assert_nothing_raised("Could not prefetch interfaces from %s provider" % provider.name) do
                provider.prefetch("eth0" => interface)
            end
        end
    end

    def test_instances
        @type.suitableprovider.each do |provider|
            list = nil
            assert_nothing_raised("Could not get instance list from %s" % provider.name) do
                list = provider.instances
            end
            assert(list.length > 0, "Did not get any instances from %s" % provider.name)
            list.each do |interface|
                assert_instance_of(provider, interface, "%s provider returned something other than a provider instance" % provider.name)
            end
        end
    end
end

