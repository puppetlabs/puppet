#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:user).provider(:pw)
resource_class = Puppet::Type.type(:user)

describe provider_class do
  describe "when creating users" do
    it "should run pw with no additional flags when no properties are given" do
      resource = resource_class.new(:name => "testuser")
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.addcmd.must == [provider_class.command(:pw), "useradd", "testuser"]
      provider.expects(:execute).with([provider_class.command(:pw), "useradd", "testuser"])
      provider.create
    end

    it "should use -o when allowdupe is enabled" do
      resource = resource_class.new(:name => "testuser", :allowdupe => true)
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.expects(:execute).with(includes("-o"))
      provider.create
    end
    it "should use -c with the correct argument when the comment property is set" do
      resource = resource_class.new(:name => "testuser", :comment => "Testuser Name")
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.expects(:execute).with(all_of(includes("-c"), includes("Testuser Name")))
      provider.create
    end
    it "should use -g with the correct argument when the gid property is set" do
      resource = resource_class.new(:name => "testuser", :gid => 12345)
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.expects(:execute).with(all_of(includes("-g"), includes(12345)))
      provider.create
    end
    it "should use -G with the correct argument when the groups property is set" do
      resource = resource_class.new(:name => "testuser", :groups => "group1")
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.expects(:execute).with(all_of(includes("-G"), includes("group1")))
      provider.create
    end
    it "should use -G with all the given groups when the groups property is set to an array" do
      resource = resource_class.new(:name => "testuser", :groups => ["group1", "group2"])
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.expects(:execute).with(all_of(includes("-G"), includes("group1,group2")))
      provider.create
    end
    it "should use -d with the correct argument when the home property is set" do
      resource = resource_class.new(:name => "testuser", :home => "/home/testuser")
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.expects(:execute).with(all_of(includes("-d"), includes("/home/testuser")))
      provider.create
    end
    it "should use -m when the managehome property is enabled" do
      resource = resource_class.new(:name => "testuser", :managehome => true)
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.expects(:execute).with(includes("-m"))
      provider.create
    end
    it "should call the password set function with the correct argument when the password property is set" do
      resource = resource_class.new(:name => "testuser", :password => "*")
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.expects(:execute)
      provider.expects(:password=).with("*")
      provider.create
    end
    it "should use -s with the correct argument when the shell property is set" do
      resource = resource_class.new(:name => "testuser", :shell => "/bin/sh")
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.expects(:execute).with(all_of(includes("-s"), includes("/bin/sh")))
      provider.create
    end
    it "should use -u with the correct argument when the uid property is set" do
      resource = resource_class.new(:name => "testuser", :uid => 12345)
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.expects(:execute).with(all_of(includes("-u"), includes(12345)))
      provider.create
    end

    # This will break if the order of arguments change. To be observed.
    it "should give a full command with all flags when eveything is set" do
      resource = resource_class.new(:name => "testuser", :allowdupe => true, :comment => "Testuser Name", :gid => 12345, :groups => ["group1", "group2"], :home => "/home/testuser", :managehome => true, :password => "*", :shell => "/bin/sh", :uid => 12345)
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.addcmd.must == [provider_class.command(:pw), "useradd", "testuser", "-c", "Testuser Name", "-d", "/home/testuser", "-s", "/bin/sh", "-u", 12345, "-G", "group1,group2", "-g", 12345, "-o", "-m"]
      provider.expects(:execute).with([provider_class.command(:pw), "useradd", "testuser", "-c", "Testuser Name", "-d", "/home/testuser", "-s", "/bin/sh", "-u", 12345, "-G", "group1,group2", "-g", 12345, "-o", "-m"])
      provider.expects(:password=).with("*")
      provider.create
    end

    # (#7500) -p should not be used to set a password (it means something else)
    it "should not use -p when a password is given" do
      resource = resource_class.new(:name => "testuser", :password => "*")
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns nil
      provider.addcmd.should_not include("-p")
      provider.expects(:password=)
      provider.expects(:execute).with(Not(includes("-p")))
      provider.create
    end
  end

  describe "when deleting users" do
    it "should run pw with no additional flags" do
      resource = resource_class.new(:name => "testuser")
      provider = provider_class.new(resource)
      provider.expects(:exists?).returns true
      provider.deletecmd.must == [provider_class.command(:pw), "userdel", "testuser"]
      provider.expects(:execute).with([provider_class.command(:pw), "userdel", "testuser"])
      provider.delete
    end
  end

  describe "when modifying users" do
    it "should run pw with the correct arguments" do
      resource = resource_class.new(:name => "testuser")
      provider = provider_class.new(resource)
      provider.modifycmd("uid", 12345).must == [provider_class.command(:pw), "usermod", "testuser", "-u", 12345]
      provider.expects(:execute).with([provider_class.command(:pw), "usermod", "testuser", "-u", 12345])
      provider.uid = 12345
    end

    it "should use -c with the correct argument when the comment property is changed" do
      resource = resource_class.new(:name => "testuser", :comment => "Testuser Name")
      provider = provider_class.new(resource)
      provider.expects(:execute).with(all_of(includes("-c"), includes("Testuser New Name")))
      provider.comment = "Testuser New Name"
    end
    it "should use -g with the correct argument when the gid property is changed" do
      resource = resource_class.new(:name => "testuser", :gid => 12345)
      provider = provider_class.new(resource)
      provider.expects(:execute).with(all_of(includes("-g"), includes(54321)))
      provider.gid = 54321
    end
    it "should use -G with the correct argument when the groups property is changed" do
      resource = resource_class.new(:name => "testuser", :groups => "group1")
      provider = provider_class.new(resource)
      provider.expects(:execute).with(all_of(includes("-G"), includes("group2")))
      provider.groups = "group2"
    end
    it "should use -G with all the given groups when the groups property is changed with an array" do
      resource = resource_class.new(:name => "testuser", :groups => ["group1", "group2"])
      provider = provider_class.new(resource)
      provider.expects(:execute).with(all_of(includes("-G"), includes("group3,group4")))
      provider.groups = "group3,group4"
    end
    it "should use -d with the correct argument when the home property is changed" do
      resource = resource_class.new(:name => "testuser", :home => "/home/testuser")
      provider = provider_class.new(resource)
      provider.expects(:execute).with(all_of(includes("-d"), includes("/newhome/testuser")))
      provider.home = "/newhome/testuser"
    end
    it "should use -m and -d with the correct argument when the home property is changed and managehome is enabled" do
      resource = resource_class.new(:name => "testuser", :home => "/home/testuser", :managehome => true)
      provider = provider_class.new(resource)
      provider.expects(:execute).with(all_of(includes("-d"), includes("/newhome/testuser"), includes("-m")))
      provider.home = "/newhome/testuser"
    end
    it "should call the password set function with the correct argument when the password property is changed" do
      resource = resource_class.new(:name => "testuser", :password => "*")
      provider = provider_class.new(resource)
      provider.expects(:password=).with("!")
      provider.password = "!"
    end
    it "should use -s with the correct argument when the shell property is changed" do
      resource = resource_class.new(:name => "testuser", :shell => "/bin/sh")
      provider = provider_class.new(resource)
      provider.expects(:execute).with(all_of(includes("-s"), includes("/bin/tcsh")))
      provider.shell = "/bin/tcsh"
    end
    it "should use -u with the correct argument when the uid property is changed" do
      resource = resource_class.new(:name => "testuser", :uid => 12345)
      provider = provider_class.new(resource)
      provider.expects(:execute).with(all_of(includes("-u"), includes(54321)))
      provider.uid = 54321
    end
  end
end
