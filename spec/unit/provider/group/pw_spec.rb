#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:group).provider(:pw)

describe provider_class do
  let :resource do
    Puppet::Type.type(:group).new(:name => "testgroup", :provider => :pw)
  end

  let :provider do
    resource.provider
  end

  describe "when creating groups" do
    let :provider do
      prov = resource.provider
      prov.expects(:exists?).returns nil
      prov
    end

    it "should run pw with no additional flags when no properties are given" do
      expect(provider.addcmd).to eq([provider_class.command(:pw), "groupadd", "testgroup"])
      provider.expects(:execute).with([provider_class.command(:pw), "groupadd", "testgroup"], kind_of(Hash))
      provider.create
    end

    it "should use -o when allowdupe is enabled" do
      resource[:allowdupe] = true
      provider.expects(:execute).with(includes("-o"), kind_of(Hash))
      provider.create
    end

    it "should use -g with the correct argument when the gid property is set" do
      resource[:gid] = 12345
      provider.expects(:execute).with(all_of(includes("-g"), includes(12345)), kind_of(Hash))
      provider.create
    end

    it "should use -M with the correct argument when the members property is set" do
      resource[:members] = "user1"
      provider.expects(:execute).with(all_of(includes("-M"), includes("user1")), kind_of(Hash))
      provider.create
    end

    it "should use -M with all the given users when the members property is set to an array" do
      resource[:members] = ["user1", "user2"]
      provider.expects(:execute).with(all_of(includes("-M"), includes("user1,user2")), kind_of(Hash))
      provider.create
    end
  end

  describe "when deleting groups" do
    it "should run pw with no additional flags" do
      provider.expects(:exists?).returns true
      expect(provider.deletecmd).to eq([provider_class.command(:pw), "groupdel", "testgroup"])
      provider.expects(:execute).with([provider_class.command(:pw), "groupdel", "testgroup"])
      provider.delete
    end
  end

  describe "when modifying groups" do
    it "should run pw with the correct arguments" do
      expect(provider.modifycmd("gid", 12345)).to eq([provider_class.command(:pw), "groupmod", "testgroup", "-g", 12345])
      provider.expects(:execute).with([provider_class.command(:pw), "groupmod", "testgroup", "-g", 12345])
      provider.gid = 12345
    end

    it "should use -M with the correct argument when the members property is changed" do
      resource[:members] = "user1"
      provider.expects(:execute).with(all_of(includes("-M"), includes("user2")))
      provider.members = "user2"
    end

    it "should use -M with all the given users when the members property is changed with an array" do
      resource[:members] = ["user1", "user2"]
      provider.expects(:execute).with(all_of(includes("-M"), includes("user3,user4")))
      provider.members = ["user3", "user4"]
    end
  end
end
