#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2006-11-12.
#  Copyright (c) 2006. All rights reserved.

$:.unshift("../../../lib") if __FILE__ =~ /\.rb$/

require 'puppettest'

if Puppet::Type.type(:host).provider(:netinfo).suitable?
class TestNetinfoHostProvider < Test::Unit::TestCase
	include PuppetTest
	
	def setup
	    super
	    @host = Puppet::Type.type(:host)
	    @provider = @host.provider(:netinfo)
    end

	def test_list
	    list = nil
	    assert_nothing_raised do
	        list = @provider.instances
        end
        assert(list.length > 0)
        list.each do |prov|
            assert_instance_of(@provider, prov)
            assert(prov.name, "objects do not have names")
            assert(prov.ip, "Did not get value for device in %s" % prov.ip)
        end

        assert(list.detect { |provider| provider.name == "localhost"}, "Could not find localhost")
    end
    
    if Process.uid == 0
    def test_simple
        localhost = nil
        assert_nothing_raised do
            localhost = @host.create :name => "localhost", :check => [:ip], :provider => :netinfo
        end
        
        assert_nothing_raised do
            localhost.retrieve
        end
        
        prov = localhost.provider
        
        assert_nothing_raised do
            assert(prov.ip, "Did not find value for ip")
            assert(prov.ip != :absent, "Netinfo thinks the localhost is missing")
        end
    end
end
end
end

