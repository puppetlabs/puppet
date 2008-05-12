#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2008-3-10.
#  Copyright (c) 2006. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

provider_class = Puppet::Type.type(:user).provider(:ldap)

describe provider_class do
    it "should have the Ldap provider class as its baseclass" do
        provider_class.superclass.should equal(Puppet::Provider::Ldap)
    end

    it "should manage :posixAccount and :person objectclasses" do
        provider_class.manager.objectclasses.should == [:posixAccount, :person]
    end

    it "should use 'ou=People' as its relative base" do
        provider_class.manager.location.should == "ou=People"
    end

    it "should use :uid as its rdn" do
        provider_class.manager.rdn.should == :uid
    end

    {:name => "uid",
        :password => "userPassword",
        :comment => "cn",
        :uid => "uidNumber",
        :gid => "gidNumber",
        :home => "homeDirectory",
        :shell => "loginShell"
    }.each do |puppet, ldap|
        it "should map :#{puppet.to_s} to '#{ldap}'" do
            provider_class.manager.ldap_name(puppet).should == ldap
        end
    end

    describe "when being created" do
        before do
            # So we don't try to actually talk to ldap
            @connection = mock 'connection'
            provider_class.manager.stubs(:connect).yields @connection
        end

        it "should generate the sn as the last field of the cn" do
            resource = stub 'resource', :should => %w{whatever}
            resource.stubs(:should).with(:comment).returns ["Luke Kanies"]
            resource.stubs(:should).with(:ensure).returns :present
            instance = provider_class.new(:name => "luke", :ensure => :absent)
            instance.stubs(:resource).returns resource

            @connection.expects(:add).with { |dn, attrs| attrs["sn"] == ["Kanies"] }

            instance.create
            instance.flush
        end

        describe "with no uid specified" do
            it "should pick the first available UID after the largest existing UID" do
                low = {:name=>["luke"], :shell=>:absent, :uid=>["100"], :home=>["/h"], :gid=>["1000"], :password=>["blah"], :comment=>["l k"]}
                high = {:name=>["testing"], :shell=>:absent, :uid=>["140"], :home=>["/h"], :gid=>["1000"], :password=>["blah"], :comment=>["t u"]}
                provider_class.manager.expects(:search).returns([low, high])

                resource = stub 'resource', :should => %w{whatever}
                resource.stubs(:should).with(:uid).returns nil
                resource.stubs(:should).with(:ensure).returns :present
                instance = provider_class.new(:name => "luke", :ensure => :absent)
                instance.stubs(:resource).returns resource

                @connection.expects(:add).with { |dn, attrs| attrs["uidNumber"] == ["141"] }

                instance.create
                instance.flush
            end
        end
    end

    describe "when flushing" do
        before do
            provider_class.stubs(:suitable?).returns true

            @instance = provider_class.new(:name => "myname", :groups => %w{whatever}, :uid => "400")
        end

        it "should remove the :groups value before updating" do
            @instance.class.manager.expects(:update).with { |name, ldap, puppet| puppet[:groups].nil? }

            @instance.flush
        end

        it "should empty the property hash" do
            @instance.class.manager.stubs(:update)

            @instance.flush

            @instance.uid.should == :absent
        end

        it "should empty the ldap property hash" do
            @instance.class.manager.stubs(:update)

            @instance.flush

            @instance.ldap_properties[:uid].should be_nil
        end
    end

    describe "when checking group membership" do
        before do
            @groups = Puppet::Type.type(:group).provider(:ldap)
            @group_manager = @groups.manager
            provider_class.stubs(:suitable?).returns true

            @instance = provider_class.new(:name => "myname")
        end

        it "should show its group membership as the list of all groups returned by an ldap query of group memberships" do
            one = {:name => "one"}
            two = {:name => "two"}
            @group_manager.expects(:search).with("memberUid=myname").returns([one, two])

            @instance.groups.should == "one,two"
        end

        it "should show its group membership as :absent if no matching groups are found in ldap" do
            @group_manager.expects(:search).with("memberUid=myname").returns(nil)

            @instance.groups.should == :absent
        end

        it "should cache the group value" do
            @group_manager.expects(:search).with("memberUid=myname").once.returns nil

            @instance.groups
            @instance.groups.should == :absent
        end
    end

    describe "when modifying group membership" do
        before do
            @groups = Puppet::Type.type(:group).provider(:ldap)
            @group_manager = @groups.manager
            provider_class.stubs(:suitable?).returns true

            @one = {:name => "one", :gid => "500"}
            @group_manager.stubs(:find).with("one").returns(@one)

            @two = {:name => "one", :gid => "600"}
            @group_manager.stubs(:find).with("two").returns(@two)

            @instance = provider_class.new(:name => "myname")

            @instance.stubs(:groups).returns :absent
        end

        it "should fail if the group does not exist" do
            @group_manager.expects(:find).with("mygroup").returns nil

            lambda { @instance.groups = "mygroup" }.should raise_error(Puppet::Error)
        end

        it "should only pass the attributes it cares about to the group manager" do
            @group_manager.expects(:update).with { |name, attrs| attrs[:gid].nil? }

            @instance.groups = "one"
        end

        it "should always include :ensure => :present in the current values" do
            @group_manager.expects(:update).with { |name, is, should| is[:ensure] == :present }

            @instance.groups = "one"
        end

        it "should always include :ensure => :present in the desired values" do
            @group_manager.expects(:update).with { |name, is, should| should[:ensure] == :present }

            @instance.groups = "one"
        end

        it "should always pass the group's original member list" do
            @one[:members] = %w{yay ness}
            @group_manager.expects(:update).with { |name, is, should| is[:members] == %w{yay ness} }

            @instance.groups = "one"
        end

        it "should find the group again when resetting its member list, so it has the full member list" do
            @group_manager.expects(:find).with("one").returns(@one)

            @group_manager.stubs(:update)

            @instance.groups = "one"
        end

        describe "for groups that have no members" do
            it "should create a new members attribute with its value being the user's name" do
                @group_manager.expects(:update).with { |name, is, should| should[:members] == %w{myname} }

                @instance.groups = "one"
            end
        end

        describe "for groups it is being removed from" do
            it "should replace the group's member list with one missing the user's name" do
                @one[:members] = %w{myname a}
                @two[:members] = %w{myname b}

                @group_manager.expects(:update).with { |name, is, should| name == "two" and should[:members] == %w{b} }

                @instance.stubs(:groups).returns "one,two"
                @instance.groups = "one"
            end

            it "should mark the member list as empty if there are no remaining members" do
                @one[:members] = %w{myname}
                @two[:members] = %w{myname b}

                @group_manager.expects(:update).with { |name, is, should| name == "one" and should[:members] == :absent }

                @instance.stubs(:groups).returns "one,two"
                @instance.groups = "two"
            end
        end

        describe "for groups that already have members" do
            it "should replace each group's member list with a new list including the user's name" do
                @one[:members] = %w{a b}
                @group_manager.expects(:update).with { |name, is, should| should[:members] == %w{a b myname} }
                @two[:members] = %w{b c}
                @group_manager.expects(:update).with { |name, is, should| should[:members] == %w{b c myname} }

                @instance.groups = "one,two"
            end
        end

        describe "for groups of which it is a member" do
            it "should do nothing" do
                @one[:members] = %w{a b}
                @group_manager.expects(:update).with { |name, is, should| should[:members] == %w{a b myname} }

                @two[:members] = %w{c myname}
                @group_manager.expects(:update).with { |name, *other| name == "two" }.never

                @instance.stubs(:groups).returns "two"

                @instance.groups = "one,two"
            end
        end
    end
end
