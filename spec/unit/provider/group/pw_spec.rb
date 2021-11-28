require 'spec_helper'

describe Puppet::Type.type(:group).provider(:pw) do
  let :resource do
    Puppet::Type.type(:group).new(:name => "testgroup", :provider => :pw)
  end

  let :provider do
    resource.provider
  end

  describe "when creating groups" do
    let :provider do
      prov = resource.provider
      expect(prov).to receive(:exists?).and_return(nil)
      prov
    end

    it "should run pw with no additional flags when no properties are given" do
      expect(provider.addcmd).to eq([described_class.command(:pw), "groupadd", "testgroup"])
      expect(provider).to receive(:execute).with([described_class.command(:pw), "groupadd", "testgroup"], kind_of(Hash))
      provider.create
    end

    it "should use -o when allowdupe is enabled" do
      resource[:allowdupe] = true
      expect(provider).to receive(:execute).with(include("-o"), kind_of(Hash))
      provider.create
    end

    it "should use -g with the correct argument when the gid property is set" do
      resource[:gid] = 12345
      expect(provider).to receive(:execute).with(include("-g") & include(12345), kind_of(Hash))
      provider.create
    end

    it "should use -M with the correct argument when the members property is set" do
      resource[:members] = "user1"
      expect(provider).to receive(:execute).with(include("-M") & include("user1"), kind_of(Hash))
      provider.create
    end

    it "should use -M with all the given users when the members property is set to an array" do
      resource[:members] = ["user1", "user2"]
      expect(provider).to receive(:execute).with(include("-M") & include("user1,user2"), kind_of(Hash))
      provider.create
    end

    it "should use -g when creating system users" do
      allow(provider).to receive(:next_system_gid).and_return(123)
      resource[:system] = true
      expect(provider).to receive(:execute).with([described_class.command(:pw), "groupadd", "testgroup", "-g", 123], kind_of(Hash))
      provider.create
    end
  end

  describe "when deleting groups" do
    it "should run pw with no additional flags" do
      expect(provider).to receive(:exists?).and_return(true)
      expect(provider.deletecmd).to eq([described_class.command(:pw), "groupdel", "testgroup"])
      expect(provider).to receive(:execute).with([described_class.command(:pw), "groupdel", "testgroup"], hash_including(:custom_environment => {}))
      provider.delete
    end
  end

  describe "when modifying groups" do
    it "should run pw with the correct arguments" do
      expect(provider.modifycmd("gid", 12345)).to eq([described_class.command(:pw), "groupmod", "testgroup", "-g", 12345])
      expect(provider).to receive(:execute).with([described_class.command(:pw), "groupmod", "testgroup", "-g", 12345], hash_including(:custom_environment => {}))
      provider.gid = 12345
    end

    it "should use -M with the correct argument when the members property is changed" do
      resource[:members] = "user1"
      expect(provider).to receive(:execute).with(include("-M") & include("user2"), hash_including(:custom_environment, {}))
      provider.members = "user2"
    end

    it "should use -M with all the given users when the members property is changed with an array" do
      resource[:members] = ["user1", "user2"]
      expect(provider).to receive(:execute).with(include("-M") & include("user3,user4"), hash_including(:custom_environment, {}))
      provider.members = ["user3", "user4"]
    end
  end
end
