#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:group).provider(:ldap)

describe provider_class do
  it "should have the Ldap provider class as its baseclass" do
    expect(provider_class.superclass).to equal(Puppet::Provider::Ldap)
  end

  it "should manage :posixGroup objectclass" do
    expect(provider_class.manager.objectclasses).to eq([:posixGroup])
  end

  it "should use 'ou=Groups' as its relative base" do
    expect(provider_class.manager.location).to eq("ou=Groups")
  end

  it "should use :cn as its rdn" do
    expect(provider_class.manager.rdn).to eq(:cn)
  end

  it "should map :name to 'cn'" do
    expect(provider_class.manager.ldap_name(:name)).to eq('cn')
  end

  it "should map :gid to 'gidNumber'" do
    expect(provider_class.manager.ldap_name(:gid)).to eq('gidNumber')
  end

  it "should map :members to 'memberUid', to be used by the user ldap provider" do
    expect(provider_class.manager.ldap_name(:members)).to eq('memberUid')
  end

  describe "when being created" do
    before do
      # So we don't try to actually talk to ldap
      @connection = mock 'connection'
      provider_class.manager.stubs(:connect).yields @connection
    end

    describe "with no gid specified" do
      it "should pick the first available GID after the largest existing GID" do
        low = {:name=>["luke"], :gid=>["600"]}
        high = {:name=>["testing"], :gid=>["640"]}
        provider_class.manager.expects(:search).returns([low, high])

        resource = stub 'resource', :should => %w{whatever}
        resource.stubs(:should).with(:gid).returns nil
        resource.stubs(:should).with(:ensure).returns :present
        instance = provider_class.new(:name => "luke", :ensure => :absent)
        instance.stubs(:resource).returns resource

        @connection.expects(:add).with { |dn, attrs| attrs["gidNumber"] == ["641"] }

        instance.create
        instance.flush
      end

      it "should pick '501' as its GID if no groups are found" do
        provider_class.manager.expects(:search).returns nil

        resource = stub 'resource', :should => %w{whatever}
        resource.stubs(:should).with(:gid).returns nil
        resource.stubs(:should).with(:ensure).returns :present
        instance = provider_class.new(:name => "luke", :ensure => :absent)
        instance.stubs(:resource).returns resource

        @connection.expects(:add).with { |dn, attrs| attrs["gidNumber"] == ["501"] }

        instance.create
        instance.flush
      end
    end
  end

  it "should have a method for converting group names to GIDs" do
    expect(provider_class).to respond_to(:name2id)
  end

  describe "when converting from a group name to GID" do
    it "should use the ldap manager to look up the GID" do
      provider_class.manager.expects(:search).with("cn=foo")
      provider_class.name2id("foo")
    end

    it "should return nil if no group is found" do
      provider_class.manager.expects(:search).with("cn=foo").returns nil
      expect(provider_class.name2id("foo")).to be_nil
      provider_class.manager.expects(:search).with("cn=bar").returns []
      expect(provider_class.name2id("bar")).to be_nil
    end

    # We shouldn't ever actually have more than one gid, but it doesn't hurt
    # to test for the possibility.
    it "should return the first gid from the first returned group" do
      provider_class.manager.expects(:search).with("cn=foo").returns [{:name => "foo", :gid => [10, 11]}, {:name => :bar, :gid => [20, 21]}]
      expect(provider_class.name2id("foo")).to eq(10)
    end
  end
end
