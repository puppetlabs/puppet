#!/usr/bin/env rspec
require 'spec_helper'

provider_class = Puppet::Type.type(:user).provider(:user_role_add)

describe provider_class, :fails_on_windows => true do
  before do
    @resource = stub("resource", :name => "myuser", :managehome? => nil)
    @resource.stubs(:should).returns "fakeval"
    @resource.stubs(:[]).returns "fakeval"
    @resource.stubs(:allowdupe?).returns false
    @provider = provider_class.new(@resource)
  end

  describe "when calling command" do
    before do
      klass = stub("provider")
      klass.stubs(:command).with(:foo).returns("userfoo")
      klass.stubs(:command).with(:role_foo).returns("rolefoo")
      @provider.stubs(:class).returns(klass)
    end

    it "should use the command if not a role and ensure!=role" do
      @provider.stubs(:is_role?).returns(false)
      @provider.stubs(:exists?).returns(false)
      @resource.stubs(:[]).with(:ensure).returns(:present)
      @provider.command(:foo).should == "userfoo"
    end

    it "should use the role command when a role" do
      @provider.stubs(:is_role?).returns(true)
      @provider.command(:foo).should == "rolefoo"
    end

    it "should use the role command when !exists and ensure=role" do
      @provider.stubs(:is_role?).returns(false)
      @provider.stubs(:exists?).returns(false)
      @resource.stubs(:[]).with(:ensure).returns(:role)
      @provider.command(:foo).should == "rolefoo"
    end
  end

  describe "when calling transition", :'fails_on_ruby_1.9.2' => true do
    it "should return the type set to whatever is passed in" do
      @provider.expects(:command).with(:modify).returns("foomod")
      @provider.transition("bar").include?("type=bar")
    end
  end

  describe "when calling create" do
    before do
      @provider.stubs(:password=)
    end

    it "should use the add command when the user is not a role" do
      @provider.stubs(:is_role?).returns(false)
      @provider.expects(:addcmd).returns("useradd")
      @provider.expects(:run).at_least_once
      @provider.create
    end

    it "should use transition(normal) when the user is a role" do
      @provider.stubs(:is_role?).returns(true)
      @provider.expects(:transition).with("normal")
      @provider.expects(:run)
      @provider.create
    end

    it "should set password age rules" do
      @resource = Puppet::Type.type(:user).new :name => "myuser", :password_min_age => 5, :password_max_age => 10, :provider => :user_role_add
      @provider = provider_class.new(@resource)
      @provider.stubs(:user_attributes)
      @provider.stubs(:execute)
      @provider.expects(:execute).with { |cmd, *args| args == ["-n", 5, "-x", 10, "myuser"] }
      @provider.create
    end
  end

  describe "when calling destroy" do
    it "should use the delete command if the user exists and is not a role" do
      @provider.stubs(:exists?).returns(true)
      @provider.stubs(:is_role?).returns(false)
      @provider.expects(:deletecmd)
      @provider.expects(:run)
      @provider.destroy
    end

    it "should use the delete command if the user is a role" do
      @provider.stubs(:exists?).returns(true)
      @provider.stubs(:is_role?).returns(true)
      @provider.expects(:deletecmd)
      @provider.expects(:run)
      @provider.destroy
    end
  end

  describe "when calling create_role" do
    it "should use the transition(role) if the user exists" do
      @provider.stubs(:exists?).returns(true)
      @provider.stubs(:is_role?).returns(false)
      @provider.expects(:transition).with("role")
      @provider.expects(:run)
      @provider.create_role
    end

    it "should use the add command when role doesn't exists" do
      @provider.stubs(:exists?).returns(false)
      @provider.expects(:addcmd)
      @provider.expects(:run)
      @provider.create_role
    end
  end

  describe "when allow duplicate is enabled" do
    before do
      @resource.expects(:allowdupe?).returns true
      @resource.stubs(:system?)
      @provider.stubs(:is_role?).returns(false)
      @provider.stubs(:execute)
      @provider.expects(:execute).with { |args| args.include?("-o") }
    end

    it "should add -o when the user is being created", :'fails_on_ruby_1.9.2' => true do
      @provider.stubs(:password=)
      @provider.create
    end

    it "should add -o when the uid is being modified" do
      @provider.uid = 150
    end
  end

  [:roles, :auths, :profiles].each do |val|
    describe "when getting #{val}" do
      it "should get the user_attributes" do
        @provider.expects(:user_attributes)
        @provider.send(val)
      end

      it "should get the #{val} attribute" do
        attributes = mock("attributes")
        attributes.expects(:[]).with(val)
        @provider.stubs(:user_attributes).returns(attributes)
        @provider.send(val)
      end
    end
  end

  describe "when getting the keys" do
    it "should get the user_attributes" do
      @provider.expects(:user_attributes)
      @provider.keys
    end

    it "should call removed_managed_attributes" do
      @provider.stubs(:user_attributes).returns({ :type => "normal", :foo => "something" })
      @provider.expects(:remove_managed_attributes)
      @provider.keys
    end

    it "should removed managed attribute (type, auths, roles, etc)" do
      @provider.stubs(:user_attributes).returns({ :type => "normal", :foo => "something" })
      @provider.keys.should == { :foo => "something" }
    end
  end

  describe "when adding properties" do
    it "should call build_keys_cmd" do
      @resource.stubs(:should).returns ""
      @resource.expects(:should).with(:keys).returns({ :foo => "bar" })
      @provider.expects(:build_keys_cmd).returns([])
      @provider.add_properties
    end

    it "should add the elements of the keys hash to an array" do
      @resource.stubs(:should).returns ""
      @resource.expects(:should).with(:keys).returns({ :foo => "bar"})
      @provider.add_properties.must == ["-K", "foo=bar"]
    end
  end

  describe "when calling build_keys_cmd" do
    it "should build cmd array with keypairs seperated by -K ending with user" do
      @provider.build_keys_cmd({"foo" => "bar", "baz" => "boo"}).should.eql? ["-K", "foo=bar", "-K", "baz=boo"]
    end
  end

  describe "when setting the keys" do
    before do
      @provider.stubs(:is_role?).returns(false)
    end

    it "should run a command" do
      @provider.expects(:run)
      @provider.keys=({})
    end

    it "should build the command" do
      @resource.stubs(:[]).with(:name).returns("someuser")
      @provider.stubs(:command).returns("usermod")
      @provider.expects(:build_keys_cmd).returns(["-K", "foo=bar"])
      @provider.expects(:run).with(["usermod", "-K", "foo=bar", "someuser"], "modify attribute key pairs")
      @provider.keys=({})
    end
  end

  describe "when getting the hashed password" do
    before do
      @array = mock "array"
    end

    it "should readlines of /etc/shadow" do
      File.expects(:readlines).with("/etc/shadow").returns([])
      @provider.password
    end

    it "should reject anything that doesn't start with alpha numerics" do
      @array.expects(:reject).returns([])
      File.stubs(:readlines).with("/etc/shadow").returns(@array)
      @provider.password
    end

    it "should collect splitting on ':'" do
      @array.stubs(:reject).returns(@array)
      @array.expects(:collect).returns([])
      File.stubs(:readlines).with("/etc/shadow").returns(@array)
      @provider.password
    end

    it "should find the matching user" do
      @resource.stubs(:[]).with(:name).returns("username")
      @array.stubs(:reject).returns(@array)
      @array.stubs(:collect).returns([["username", "hashedpassword"], ["someoneelse", "theirpassword"]])
      File.stubs(:readlines).with("/etc/shadow").returns(@array)
      @provider.password.must == "hashedpassword"
    end

    it "should get the right password" do
      @resource.stubs(:[]).with(:name).returns("username")
      File.stubs(:readlines).with("/etc/shadow").returns(["#comment", "   nonsense", "  ", "username:hashedpassword:stuff:foo:bar:::", "other:pword:yay:::"])
      @provider.password.must == "hashedpassword"
    end
  end

  describe "when setting the password" do
    #how can you mock these blocks up?
    it "should open /etc/shadow for reading and /etc/shadow_tmp for writing" do
      File.expects(:open).with("/etc/shadow", "r")
      File.stubs(:rename)
      @provider.password=("hashedpassword")
    end

    it "should rename the /etc/shadow_tmp to /etc/shadow" do
      File.stubs(:open).with("/etc/shadow", "r")
      File.expects(:rename).with("/etc/shadow_tmp", "/etc/shadow")
      @provider.password=("hashedpassword")
    end
  end

  describe "#shadow_entry" do
    it "should return the line for the right user" do
      File.stubs(:readlines).returns(["someuser:!:10:5:20:7:1::\n", "fakeval:*:20:10:30:7:2::\n", "testuser:*:30:15:40:7:3::\n"])
      @provider.shadow_entry.should == ["fakeval", "*", "20", "10", "30", "7", "2"]
    end
  end
end
