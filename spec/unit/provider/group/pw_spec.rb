#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:group).provider(:pw)
resource_class = Puppet::Type.type(:group)

describe provider_class do
  describe "when creating groups" do
    it "should run pw with no additional flags when no properties are given" do
      resource = resource_class.new(:name => "testgroup")
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.addcmd.must == [provider_class.command(:pw), "groupadd", "testgroup"]
      provider.expects(:execute).with([provider_class.command(:pw), "groupadd", "testgroup"])
      provider.create
    end

    it "should use -o when allowdupe is enabled" do
      resource = resource_class.new(:name => "testgroup", :allowdupe => true)
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.expects(:execute).with(includes("-o"))
      provider.create
    end
    it "should use -g with the correct argument when the gid property is set" do
      resource = resource_class.new(:name => "testgroup", :gid => 12345)
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.expects(:execute).with(all_of(includes("-g"), includes(12345)))
      provider.create
    end
    it "should use -M with the correct argument when the members property is set" do
      resource = resource_class.new(:name => "testgroup", :members => "user1")
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.expects(:execute).with(all_of(includes("-M"), includes("user1")))
      provider.create
    end
    it "should use -M with all the given users when the members property is set to an array" do
      resource = resource_class.new(:name => "testgroup", :members => ["user1", "user2"])
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.expects(:execute).with(all_of(includes("-M"), includes("user1,user2")))
      provider.create
    end

    # This will break if the order of arguments change. To be observed.
    it "should give a full command with all flags when eveything is set" do
      resource = resource_class.new(:name => "testgroup", :allowdupe => true, :gid => 12345, :members => ["user1", "user2"])
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.addcmd.must == [provider_class.command(:pw), "groupadd", "testgroup", "-g", 12345, "-M", "user1,user2", "-o"]
      provider.expects(:execute).with([provider_class.command(:pw), "groupadd", "testgroup", "-g", 12345, "-M", "user1,user2", "-o"])
      provider.create
    end
  end

  describe "when deleting groups" do
    it "should run pw with no additional flags" do
      resource = resource_class.new(:name => "testgroup")
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns true
      provider.deletecmd.must == [provider_class.command(:pw), "groupdel", "testgroup"]
      provider.expects(:execute).with([provider_class.command(:pw), "groupdel", "testgroup"])
      provider.delete
    end
  end

  describe "when modifying groups" do
    it "should run pw with the correct arguments" do
      resource = resource_class.new(:name => "testgroup")
      provider = provider_class.new(resource)
      provider.modifycmd("gid", 12345).must == [provider_class.command(:pw), "groupmod", "testgroup", "-g", 12345]
      provider.expects(:execute).with([provider_class.command(:pw), "groupmod", "testgroup", "-g", 12345])
      provider.gid = 12345
    end

    it "should use -M with the correct argument when the members property is changed" do
      resource = resource_class.new(:name => "testgroup", :members => "user1")
      provider = provider_class.new(resource)
      provider.expects(:execute).with(all_of(includes("-M"), includes("user2")))
      provider.members = "user2"
    end
    it "should use -M with all the given users when the members property is changed with an array" do
      resource = resource_class.new(:name => "testgroup", :members => ["user1", "user2"])
      provider = provider_class.new(resource)
      provider.expects(:execute).with(all_of(includes("-M"), includes("user3,user4")))
      provider.members = ["user3", "user4"]
    end
  end
end
