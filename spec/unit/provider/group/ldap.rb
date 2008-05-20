#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2008-3-10.
#  Copyright (c) 2006. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

provider_class = Puppet::Type.type(:group).provider(:ldap)

describe provider_class do
    it "should have the Ldap provider class as its baseclass" do
        provider_class.superclass.should equal(Puppet::Provider::Ldap)
    end

    it "should manage :posixGroup objectclass" do
        provider_class.manager.objectclasses.should == [:posixGroup]
    end

    it "should use 'ou=Groups' as its relative base" do
        provider_class.manager.location.should == "ou=Groups"
    end

    it "should use :cn as its rdn" do
        provider_class.manager.rdn.should == :cn
    end

    it "should map :name to 'cn'" do
        provider_class.manager.ldap_name(:name).should == 'cn'
    end

    it "should map :gid to 'gidNumber'" do
        provider_class.manager.ldap_name(:gid).should == 'gidNumber'
    end

    it "should map :members to 'memberUid', to be used by the user ldap provider" do
        provider_class.manager.ldap_name(:members).should == 'memberUid'
    end

    describe "when being created" do
        before do
            # So we don't try to actually talk to ldap
            @connection = mock 'connection'
            provider_class.manager.stubs(:connect).yields @connection
        end

        describe "with no gid specified" do
            it "should pick the first available GID after the largest existing GID" do
                low = {:name=>["luke"], :gid=>["100"]}
                high = {:name=>["testing"], :gid=>["140"]}
                provider_class.manager.expects(:search).returns([low, high])

                resource = stub 'resource', :should => %w{whatever}
                resource.stubs(:should).with(:gid).returns nil
                resource.stubs(:should).with(:ensure).returns :present
                instance = provider_class.new(:name => "luke", :ensure => :absent)
                instance.stubs(:resource).returns resource

                @connection.expects(:add).with { |dn, attrs| attrs["gidNumber"] == ["141"] }

                instance.create
                instance.flush
            end
        end
    end

end
