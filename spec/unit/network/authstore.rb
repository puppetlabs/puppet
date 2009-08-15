#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/authconfig'

describe Puppet::Network::AuthStore::Declaration do

    describe "when the pattern is simple numeric IP" do
        before :each do
            @ip = '100.101.99.98'
            @declaration = Puppet::Network::AuthStore::Declaration.new(:allow,@ip)
        end
        it "should match the specified IP" do
            @declaration.should be_match('www.testsite.org',@ip)
        end
        it "should not match other IPs" do
            @declaration.should_not be_match('www.testsite.org','200.101.99.98')
        end
    end

    describe "when the pattern is a numeric IP with a back reference" do
        before :each do
            @ip = '100.101.$1'
            @declaration = Puppet::Network::AuthStore::Declaration.new(:allow,@ip).interpolate('12.34'.match /(.*)/)
        end
        it "should match an IP with the apropriate interpolation" do
            @declaration.should be_match('www.testsite.org',@ip.sub(/\$1/,'12.34'))
        end
        it "should not match other IPs" do
            @declaration.should_not be_match('www.testsite.org',@ip.sub(/\$1/,'66.34'))
        end
    end

    describe "when the pattern is a PQDN" do
        before :each do
            @host = 'spirit.mars.nasa.gov'
            @declaration = Puppet::Network::AuthStore::Declaration.new(:allow,@host)
        end
        it "should match the specified PQDN" do
            pending "FQDN consensus"
            @declaration.should be_match(@host,'200.101.99.98')
        end
        it "should not match a similar FQDN" do
            pending "FQDN consensus"
            @declaration.should_not be_match(@host+'.','200.101.99.98')
        end
    end

    describe "when the pattern is a FQDN" do
        before :each do
            @host = 'spirit.mars.nasa.gov.'
            @declaration = Puppet::Network::AuthStore::Declaration.new(:allow,@host)
        end
        it "should match the specified FQDN" do
            pending "FQDN consensus"
            @declaration.should be_match(@host,'200.101.99.98')
        end
        it "should not match a similar PQDN" do
            pending "FQDN consensus"
            @declaration.should_not be_match(@host[0..-2],'200.101.99.98')
        end
    end


    describe "when the pattern is an opaque string with a back reference" do
        before :each do
            @host = 'c216f41a-f902-4bfb-a222-850dd957bebb'
            @item = "/catalog/#{@host}"
            @pattern = %{^/catalog/([^/]+)$}
            @declaration = Puppet::Network::AuthStore::Declaration.new(:allow,'$1')
        end
        it "should match an IP with the apropriate interpolation" do
            @declaration.interpolate(@item.match(@pattern)).should be_match(@host,'10.0.0.5')
        end
    end

    describe "when comparing patterns" do
        before :each do
            @ip        = Puppet::Network::AuthStore::Declaration.new(:allow,'127.0.0.1')
            @host_name = Puppet::Network::AuthStore::Declaration.new(:allow,'www.hard_knocks.edu')
            @opaque    = Puppet::Network::AuthStore::Declaration.new(:allow,'hey_dude')
        end
        it "should consider ip addresses before host names" do
            (@ip < @host_name).should be_true
        end
        it "should consider ip addresses before opaque strings" do
            (@ip < @opaque).should be_true
        end
        it "should consider host_names before opaque strings" do
            (@host_name < @opaque).should be_true
        end
    end
end
