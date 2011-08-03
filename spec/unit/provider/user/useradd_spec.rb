#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:user).provider(:useradd)

describe provider_class, :fails_on_windows => true do
  before do
    @resource = stub("resource", :name => "myuser", :managehome? => nil)
    @resource.stubs(:should).returns "fakeval"
    @resource.stubs(:[]).returns "fakeval"
    @provider = provider_class.new(@resource)
  end

  # #1360
  it "should add -o when allowdupe is enabled and the user is being created" do
    @resource.expects(:allowdupe?).returns true
    @resource.expects(:system?).returns true
    @provider.stubs(:execute)
    @provider.expects(:execute).with { |args| args.include?("-o") }
    @provider.create
  end

  it "should add -o when allowdupe is enabled and the uid is being modified" do
    @resource.expects(:allowdupe?).returns true
    @provider.expects(:execute).with { |args| args.include?("-o") }

    @provider.uid = 150
  end

  it "should add -r when system is enabled" do
    @resource.expects(:allowdupe?).returns true
    @resource.expects(:system?).returns true
    @provider.stubs(:execute)
    @provider.expects(:execute).with { |args| args.include?("-r") }
    @provider.create
  end

  it "should set password age rules" do
    provider_class.has_feature :manages_password_age
    @resource = Puppet::Type.type(:user).new :name => "myuser", :password_min_age => 5, :password_max_age => 10, :provider => :useradd
    @provider = provider_class.new(@resource)
    @provider.stubs(:execute)
    @provider.expects(:execute).with { |cmd, *args| args == ["-m", 5, "-M", 10, "myuser"] }
    @provider.create
  end

  describe "when checking to add allow dup" do
    it "should check allow dup" do
      @resource.expects(:allowdupe?)
      @provider.check_allow_dup
    end

    it "should return an array with a flag if dup is allowed" do
      @resource.stubs(:allowdupe?).returns true
      @provider.check_allow_dup.must == ["-o"]
    end

    it "should return an empty array if no dup is allowed" do
      @resource.stubs(:allowdupe?).returns false
      @provider.check_allow_dup.must == []
    end
  end

  describe "when checking to add system users" do
    it "should check system users" do
      @resource.expects(:system?)
      @provider.check_system_users
    end

    it "should return an array with a flag if it's a system user" do
      @resource.stubs(:system?).returns true
      @provider.check_system_users.must == ["-r"]
    end

    it "should return an empty array if it's not a system user" do
      @resource.stubs(:system?).returns false
      @provider.check_system_users.must == []
    end
  end

  describe "when checking manage home" do
    it "should check manage home" do
      @resource.expects(:managehome?)
      @provider.check_manage_home
    end

    it "should return an array with -m flag if home is managed" do
      @resource.stubs(:managehome?).returns true
      @provider.check_manage_home.must == ["-m"]
    end

    it "should return an array with -M if home is not managed and on Redhat" do
      Facter.stubs(:value).with("operatingsystem").returns("RedHat")
      @resource.stubs(:managehome?).returns false
      @provider.check_manage_home.must == ["-M"]
    end

    it "should return an empty array if home is not managed and not on Redhat" do
      Facter.stubs(:value).with("operatingsystem").returns("some OS")
      @resource.stubs(:managehome?).returns false
      @provider.check_manage_home.must == []
    end
  end

  describe "when adding properties" do
    it "should get the valid properties"
    it "should not add the ensure property"
    it "should add the flag and value to an array"
    it "should return and array of flags and values"
  end

  describe "when calling addcmd" do
    before do
      @resource.stubs(:allowdupe?).returns true
      @resource.stubs(:managehome?).returns true
      @resource.stubs(:system?).returns true
    end

    it "should call command with :add" do
      @provider.expects(:command).with(:add)
      @provider.addcmd
    end

    it "should add properties" do
      @provider.expects(:add_properties).returns([])
      @provider.addcmd
    end

    it "should check and add if dup allowed" do
      @provider.expects(:check_allow_dup).returns([])
      @provider.addcmd
    end

    it "should check and add if home is managed" do
      @provider.expects(:check_manage_home).returns([])
      @provider.addcmd
    end

    it "should add the resource :name" do
      @resource.expects(:[]).with(:name)
      @provider.addcmd
    end

    it "should return an array with -r if system? is true" do
      resource = Puppet::Type.type(:user).new( :name => "bob", :system => true)

      provider_class.new( resource ).addcmd.should include("-r")
    end

    it "should return an array without -r if system? is false" do
      resource = Puppet::Type.type(:user).new( :name => "bob", :system => false)

      provider_class.new( resource ).addcmd.should_not include("-r")
    end

    it "should return an array with full command" do
      @provider.stubs(:command).with(:add).returns("useradd")
      @provider.stubs(:add_properties).returns(["-G", "somegroup"])
      @resource.stubs(:[]).with(:name).returns("someuser")
      @resource.stubs(:[]).with(:expiry).returns("somedate")
      @provider.addcmd.must == ["useradd", "-G", "somegroup", "-o", "-m", '-e somedate', "-r", "someuser"]
    end

    it "should return an array without -e if expiry is undefined full command" do
      @provider.stubs(:command).with(:add).returns("useradd")
      @provider.stubs(:add_properties).returns(["-G", "somegroup"])
      @resource.stubs(:[]).with(:name).returns("someuser")
      @resource.stubs(:[]).with(:expiry).returns nil
      @provider.addcmd.must == ["useradd", "-G", "somegroup", "-o", "-m", "-r", "someuser"]
    end
  end

  describe "when calling passcmd" do
    before do
      @resource.stubs(:allowdupe?).returns true
      @resource.stubs(:managehome?).returns true
      @resource.stubs(:system?).returns true
    end

    it "should call command with :pass" do
      @provider.expects(:command).with(:password)
      @provider.passcmd
    end

    it "should return nil if neither min nor max is set" do
      @resource.stubs(:should).with(:password_min_age).returns nil
      @resource.stubs(:should).with(:password_max_age).returns nil
      @provider.passcmd.must == nil
    end

    it "should return a chage command array with -m <value> and the user name if password_min_age is set" do
      @provider.stubs(:command).with(:password).returns("chage")
      @resource.stubs(:[]).with(:name).returns("someuser")
      @resource.stubs(:should).with(:password_min_age).returns 123
      @resource.stubs(:should).with(:password_max_age).returns nil
      @provider.passcmd.must == ['chage','-m',123,'someuser']
    end

    it "should return a chage command array with -M <value> if password_max_age is set" do
      @provider.stubs(:command).with(:password).returns("chage")
      @resource.stubs(:[]).with(:name).returns("someuser")
      @resource.stubs(:should).with(:password_min_age).returns nil
      @resource.stubs(:should).with(:password_max_age).returns 999
      @provider.passcmd.must == ['chage','-M',999,'someuser']
    end

    it "should return a chage command array with -M <value> -m <value> if both password_min_age and password_max_age are set" do
      @provider.stubs(:command).with(:password).returns("chage")
      @resource.stubs(:[]).with(:name).returns("someuser")
      @resource.stubs(:should).with(:password_min_age).returns 123
      @resource.stubs(:should).with(:password_max_age).returns 999
      @provider.passcmd.must == ['chage','-m',123,'-M',999,'someuser']
    end
  end
end
