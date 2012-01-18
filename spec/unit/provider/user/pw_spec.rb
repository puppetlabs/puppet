#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:user).provider(:pw)

describe provider_class do
  let :resource do
    Puppet::Type.type(:user).new(:name => "testuser", :provider => :pw)
  end

  describe "when creating users" do
    let :provider do
      prov = resource.provider
      prov.expects(:exists?).returns nil
      prov
    end

    it "should run pw with no additional flags when no properties are given" do
      provider.addcmd.must == [provider_class.command(:pw), "useradd", "testuser"]
      provider.expects(:execute).with([provider_class.command(:pw), "useradd", "testuser"])
      provider.create
    end

    it "should use -o when allowdupe is enabled" do
      resource[:allowdupe] = true
      provider.expects(:execute).with(includes("-o"))
      provider.create
    end

    it "should use -c with the correct argument when the comment property is set" do
      resource[:comment] = "Testuser Name"
      provider.expects(:execute).with(all_of(includes("-c"), includes("Testuser Name")))
      provider.create
    end

    it "should use -e with the correct argument when the expiry property is set" do
      resource[:expiry] = "2010-02-19"
      provider.expects(:execute).with(all_of(includes("-e"), includes("19-02-2010")))
      provider.create
    end

    it "should use -g with the correct argument when the gid property is set" do
      resource[:gid] = 12345
      provider.expects(:execute).with(all_of(includes("-g"), includes(12345)))
      provider.create
    end

    it "should use -G with the correct argument when the groups property is set" do
      resource[:groups] = "group1"
      provider.expects(:execute).with(all_of(includes("-G"), includes("group1")))
      provider.create
    end

    it "should use -G with all the given groups when the groups property is set to an array" do
      resource[:groups] = ["group1", "group2"]
      provider.expects(:execute).with(all_of(includes("-G"), includes("group1,group2")))
      provider.create
    end

    it "should use -d with the correct argument when the home property is set" do
      resource[:home] = "/home/testuser"
      provider.expects(:execute).with(all_of(includes("-d"), includes("/home/testuser")))
      provider.create
    end

    it "should use -m when the managehome property is enabled" do
      resource[:managehome] = true
      provider.expects(:execute).with(includes("-m"))
      provider.create
    end

    it "should call the password set function with the correct argument when the password property is set" do
      resource[:password] = "*"
      provider.expects(:execute)
      provider.expects(:password=).with("*")
      provider.create
    end

    it "should use -s with the correct argument when the shell property is set" do
      resource[:shell] = "/bin/sh"
      provider.expects(:execute).with(all_of(includes("-s"), includes("/bin/sh")))
      provider.create
    end

    it "should use -u with the correct argument when the uid property is set" do
      resource[:uid] = 12345
      provider.expects(:execute).with(all_of(includes("-u"), includes(12345)))
      provider.create
    end

    # (#7500) -p should not be used to set a password (it means something else)
    it "should not use -p when a password is given" do
      resource[:password] = "*"
      provider.addcmd.should_not include("-p")
      provider.expects(:password=)
      provider.expects(:execute).with(Not(includes("-p")))
      provider.create
    end
  end

  describe "when deleting users" do
    it "should run pw with no additional flags" do
      provider = resource.provider
      provider.expects(:exists?).returns true
      provider.deletecmd.must == [provider_class.command(:pw), "userdel", "testuser"]
      provider.expects(:execute).with([provider_class.command(:pw), "userdel", "testuser"])
      provider.delete
    end
  end

  describe "when modifying users" do
    let :provider do
      resource.provider
    end

    it "should run pw with the correct arguments" do
      provider.modifycmd("uid", 12345).must == [provider_class.command(:pw), "usermod", "testuser", "-u", 12345]
      provider.expects(:execute).with([provider_class.command(:pw), "usermod", "testuser", "-u", 12345])
      provider.uid = 12345
    end

    it "should use -c with the correct argument when the comment property is changed" do
      resource[:comment] = "Testuser Name"
      provider.expects(:execute).with(all_of(includes("-c"), includes("Testuser New Name")))
      provider.comment = "Testuser New Name"
    end

    it "should use -e with the correct argument when the expiry property is changed" do
      resource[:expiry] = "2010-02-19"
      provider.expects(:execute).with(all_of(includes("-e"), includes("19-02-2011")))
      provider.expiry = "2011-02-19"
    end

    it "should use -g with the correct argument when the gid property is changed" do
      resource[:gid] = 12345
      provider.expects(:execute).with(all_of(includes("-g"), includes(54321)))
      provider.gid = 54321
    end

    it "should use -G with the correct argument when the groups property is changed" do
      resource[:groups] = "group1"
      provider.expects(:execute).with(all_of(includes("-G"), includes("group2")))
      provider.groups = "group2"
    end

    it "should use -G with all the given groups when the groups property is changed with an array" do
      resource[:groups] = ["group1", "group2"]
      provider.expects(:execute).with(all_of(includes("-G"), includes("group3,group4")))
      provider.groups = "group3,group4"
    end

    it "should use -d with the correct argument when the home property is changed" do
      resource[:home] = "/home/testuser"
      provider.expects(:execute).with(all_of(includes("-d"), includes("/newhome/testuser")))
      provider.home = "/newhome/testuser"
    end

    it "should use -m and -d with the correct argument when the home property is changed and managehome is enabled" do
      resource[:home] = "/home/testuser"
      resource[:managehome] = true
      provider.expects(:execute).with(all_of(includes("-d"), includes("/newhome/testuser"), includes("-m")))
      provider.home = "/newhome/testuser"
    end

    it "should call the password set function with the correct argument when the password property is changed" do
      resource[:password] = "*"
      provider.expects(:password=).with("!")
      provider.password = "!"
    end

    it "should use -s with the correct argument when the shell property is changed" do
      resource[:shell] = "/bin/sh"
      provider.expects(:execute).with(all_of(includes("-s"), includes("/bin/tcsh")))
      provider.shell = "/bin/tcsh"
    end

    it "should use -u with the correct argument when the uid property is changed" do
      resource[:uid] = 12345
      provider.expects(:execute).with(all_of(includes("-u"), includes(54321)))
      provider.uid = 54321
    end
  end
end
