#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/authconfig'

describe Puppet::Network::AuthStore do
    describe "when checking if the acl has some entries" do
        before :each do
            @authstore = Puppet::Network::AuthStore.new
        end

        it "should be empty if no ACE have been entered" do
            @authstore.should be_empty
        end

        it "should not be empty if it is a global allow" do
            @authstore.allow('*')

            @authstore.should_not be_empty
        end

        it "should not be empty if at least one allow has been entered" do
            @authstore.allow('1.1.1.*')

            @authstore.should_not be_empty
        end

        it "should not be empty if at least one deny has been entered" do
            @authstore.deny('1.1.1.*')

            @authstore.should_not be_empty
        end
    end
end

describe Puppet::Network::AuthStore::Declaration do

    ['100.101.99.98','100.100.100.100','1.2.3.4','11.22.33.44'].each { |ip|
        describe "when the pattern is a simple numeric IP such as #{ip}" do
            before :each do
                @declaration = Puppet::Network::AuthStore::Declaration.new(:allow,ip)
            end
            it "should match the specified IP" do
                @declaration.should be_match('www.testsite.org',ip)
            end
            it "should not match other IPs" do
                @declaration.should_not be_match('www.testsite.org','200.101.99.98')
            end
        end

        (1..3).each { |n|
            describe "when the pattern is a IP mask with #{n} numeric segments and a *" do
                before :each do
                    @ip_pattern = ip.split('.')[0,n].join('.')+'.*'
                    @declaration = Puppet::Network::AuthStore::Declaration.new(:allow,@ip_pattern)
                end
                it "should match an IP in the range" do
                    @declaration.should be_match('www.testsite.org',ip)
                end
                it "should not match other IPs" do
                    @declaration.should_not be_match('www.testsite.org','200.101.99.98')
                end
                it "should not match IPs that differ in the last non-wildcard segment" do
                    other = ip.split('.')
                    other[n-1].succ!
                    @declaration.should_not be_match('www.testsite.org',other.join('.'))
                end
            end
        }    
    }

    describe "when the pattern is a numeric IP with a back reference" do
        before :each do
            @ip = '100.101.$1'
            @declaration = Puppet::Network::AuthStore::Declaration.new(:allow,@ip).interpolate('12.34'.match(/(.*)/))
        end
        it "should match an IP with the appropriate interpolation" do
            @declaration.should be_match('www.testsite.org',@ip.sub(/\$1/,'12.34'))
        end
        it "should not match other IPs" do
            @declaration.should_not be_match('www.testsite.org',@ip.sub(/\$1/,'66.34'))
        end
    end

    {
    'spirit.mars.nasa.gov' => 'a PQDN',
    'ratchet.2ndsiteinc.com' => 'a PQDN with digits',
    'a.c.ru' => 'a PQDN with short segments',
    }.each {|pqdn,desc|
        describe "when the pattern is #{desc}" do
            before :each do
                @host = pqdn
                @declaration = Puppet::Network::AuthStore::Declaration.new(:allow,@host)
            end
            it "should match the specified PQDN" do
                @declaration.should be_match(@host,'200.101.99.98')
            end
            it "should not match a similar FQDN" do
                pending "FQDN consensus"
                @declaration.should_not be_match(@host+'.','200.101.99.98')
            end
        end
    }

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
        it "should match an IP with the appropriate interpolation" do
            @declaration.interpolate(@item.match(@pattern)).should be_match(@host,'10.0.0.5')
        end
    end

    describe "when the pattern is an opaque string with a back reference and the matched data contains dots" do
        before :each do
            @host = 'admin.mgmt.nym1'
            @item = "/catalog/#{@host}"
            @pattern = %{^/catalog/([^/]+)$}
            @declaration = Puppet::Network::AuthStore::Declaration.new(:allow,'$1')
        end
        it "should match a name with the appropriate interpolation" do
            @declaration.interpolate(@item.match(@pattern)).should be_match(@host,'10.0.0.5')
        end
    end

    describe "when the pattern is an opaque string with a back reference and the matched data contains dots with an initial prefix that looks like an IP address" do
        before :each do
            @host = '01.admin.mgmt.nym1'
            @item = "/catalog/#{@host}"
            @pattern = %{^/catalog/([^/]+)$}
            @declaration = Puppet::Network::AuthStore::Declaration.new(:allow,'$1')
        end
        it "should match a name with the appropriate interpolation" do
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
