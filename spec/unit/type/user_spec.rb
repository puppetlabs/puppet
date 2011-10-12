#!/usr/bin/env rspec
require 'spec_helper'

user = Puppet::Type.type(:user)

describe user do
  before do
    ENV["PATH"] += File::PATH_SEPARATOR + "/usr/sbin" unless ENV["PATH"].split(File::PATH_SEPARATOR).include?("/usr/sbin")
    @provider = stub 'provider'
    @resource = stub 'resource', :resource => nil, :provider => @provider, :line => nil, :file => nil
  end

  it "should have a default provider inheriting from Puppet::Provider" do
    user.defaultprovider.ancestors.should be_include(Puppet::Provider)
  end

  it "should be able to create a instance" do
    user.new(:name => "foo").should_not be_nil
  end

  it "should have an allows_duplicates feature" do
    user.provider_feature(:allows_duplicates).should_not be_nil
  end

  it "should have an manages_homedir feature" do
    user.provider_feature(:manages_homedir).should_not be_nil
  end

  it "should have an manages_passwords feature" do
    user.provider_feature(:manages_passwords).should_not be_nil
  end

  it "should have a manages_solaris_rbac feature" do
    user.provider_feature(:manages_solaris_rbac).should_not be_nil
  end

  it "should have a manages_expiry feature" do
    user.provider_feature(:manages_expiry).should_not be_nil
  end

  it "should have a manages_password_age feature" do
    user.provider_feature(:manages_password_age).should_not be_nil
  end

  it "should have a system_users feature" do
    user.provider_feature(:system_users).should_not be_nil
  end

  describe "instances" do
    it "should have a valid provider" do
      user.new(:name => "foo").provider.class.ancestors.should be_include(Puppet::Provider)
    end

    it "should delegate existence questions to its provider" do
      instance = user.new(:name => "foo")
      instance.provider.expects(:exists?).returns "eh"
      instance.exists?.should == "eh"
    end
  end

  properties = [:ensure, :uid, :gid, :home, :comment, :shell, :password, :password_min_age, :password_max_age, :groups, :roles, :auths, :profiles, :project, :keys, :expiry]

  properties.each do |property|
    it "should have a #{property} property" do
      user.attrclass(property).ancestors.should be_include(Puppet::Property)
    end

    it "should have documentation for its #{property} property" do
      user.attrclass(property).doc.should be_instance_of(String)
    end
  end

  list_properties = [:groups, :roles, :auths]

  list_properties.each do |property|
    it "should have a list '#{property}'" do
      user.attrclass(property).ancestors.should be_include(Puppet::Property::List)
    end
  end

  it "should have an ordered list 'profiles'" do
    user.attrclass(:profiles).ancestors.should be_include(Puppet::Property::OrderedList)
  end

  it "should have key values 'keys'" do
    user.attrclass(:keys).ancestors.should be_include(Puppet::Property::KeyValue)
  end

  describe "when retrieving all current values" do
    before do
      @user = user.new(:name => "foo", :uid => 10)
    end

    it "should return a hash containing values for all set properties" do
      @user[:gid] = 10
      @user.property(:ensure).expects(:retrieve).returns :present
      @user.property(:uid).expects(:retrieve).returns 15
      @user.property(:gid).expects(:retrieve).returns 15
      values = @user.retrieve
      [@user.property(:uid), @user.property(:gid)].each { |property| values.should be_include(property) }
    end

    it "should set all values to :absent if the user is absent" do
      @user.property(:ensure).expects(:retrieve).returns :absent
      @user.property(:uid).expects(:retrieve).never
      @user.retrieve[@user.property(:uid)].should == :absent
    end

    it "should include the result of retrieving each property's current value if the user is present" do
      @user.property(:ensure).expects(:retrieve).returns :present
      @user.property(:uid).expects(:retrieve).returns 15
      @user.retrieve[@user.property(:uid)].should == 15
    end
  end

  describe "when managing the ensure property" do
    before do
      @ensure = user.attrclass(:ensure).new(:resource => @resource)
    end

    it "should support a :present value" do
      lambda { @ensure.should = :present }.should_not raise_error
    end

    it "should support an :absent value" do
      lambda { @ensure.should = :absent }.should_not raise_error
    end

    it "should call :create on the provider when asked to sync to the :present state" do
      @provider.expects(:create)
      @ensure.should = :present
      @ensure.sync
    end

    it "should call :delete on the provider when asked to sync to the :absent state" do
      @provider.expects(:delete)
      @ensure.should = :absent
      @ensure.sync
    end

    describe "and determining the current state" do
      it "should return :present when the provider indicates the user exists" do
        @provider.expects(:exists?).returns true
        @ensure.retrieve.should == :present
      end

      it "should return :absent when the provider indicates the user does not exist" do
        @provider.expects(:exists?).returns false
        @ensure.retrieve.should == :absent
      end
    end
  end

  describe "when managing the uid property" do
    it "should convert number-looking strings into actual numbers" do
      uid = user.attrclass(:uid).new(:resource => @resource)
      uid.should = "50"
      uid.should.must == 50
    end

    it "should support UIDs as numbers" do
      uid = user.attrclass(:uid).new(:resource => @resource)
      uid.should = 50
      uid.should.must == 50
    end

    it "should :absent as a value" do
      uid = user.attrclass(:uid).new(:resource => @resource)
      uid.should = :absent
      uid.should.must == :absent
    end
  end

  describe "when managing the gid" do
    it "should :absent as a value" do
      gid = user.attrclass(:gid).new(:resource => @resource)
      gid.should = :absent
      gid.should.must == :absent
    end

    it "should convert number-looking strings into actual numbers" do
      gid = user.attrclass(:gid).new(:resource => @resource)
      gid.should = "50"
      gid.should.must == 50
    end

    it "should support GIDs specified as integers" do
      gid = user.attrclass(:gid).new(:resource => @resource)
      gid.should = 50
      gid.should.must == 50
    end

    it "should support groups specified by name" do
      gid = user.attrclass(:gid).new(:resource => @resource)
      gid.should = "foo"
      gid.should.must == "foo"
    end

    describe "when testing whether in sync" do
      before do
        @gid = user.attrclass(:gid).new(:resource => @resource, :should => %w{foo bar})
      end

      it "should return true if no 'should' values are set" do
        @gid = user.attrclass(:gid).new(:resource => @resource)

        @gid.must be_safe_insync(500)
      end

      it "should return true if any of the specified groups are equal to the current integer" do
        Puppet::Util.expects(:gid).with("foo").returns 300
        Puppet::Util.expects(:gid).with("bar").returns 500

        @gid.must be_safe_insync(500)
      end

      it "should return false if none of the specified groups are equal to the current integer" do
        Puppet::Util.expects(:gid).with("foo").returns 300
        Puppet::Util.expects(:gid).with("bar").returns 500

        @gid.should_not be_safe_insync(700)
      end
    end

    describe "when syncing" do
      before do
        @gid = user.attrclass(:gid).new(:resource => @resource, :should => %w{foo bar})
      end

      it "should use the first found, specified group as the desired value and send it to the provider" do
        Puppet::Util.expects(:gid).with("foo").returns nil
        Puppet::Util.expects(:gid).with("bar").returns 500

        @provider.expects(:gid=).with 500

        @gid.sync
      end
    end
  end

  describe "when managing expiry" do
    before do
      @expiry = user.attrclass(:expiry).new(:resource => @resource)
    end

    it "should fail if given an invalid date" do
      lambda { @expiry.should = "200-20-20" }.should raise_error(Puppet::Error)
    end
  end

  describe "when managing minimum password age" do
    before do
      @age = user.attrclass(:password_min_age).new(:resource => @resource)
    end

    it "should accept a negative minimum age" do
      expect { @age.should = -1 }.should_not raise_error
    end

    it "should fail with an empty minimum age" do
      expect { @age.should = '' }.should raise_error(Puppet::Error)
    end
  end

  describe "when managing maximum password age" do
    before do
      @age = user.attrclass(:password_max_age).new(:resource => @resource)
    end

    it "should accept a negative maximum age" do
      expect { @age.should = -1 }.should_not raise_error
    end

    it "should fail with an empty maximum age" do
      expect { @age.should = '' }.should raise_error(Puppet::Error)
    end
  end

  describe "when managing passwords" do
    before do
      @password = user.attrclass(:password).new(:resource => @resource, :should => "mypass")
    end

    it "should not include the password in the change log when adding the password" do
      @password.change_to_s(:absent, "mypass").should_not be_include("mypass")
    end

    it "should not include the password in the change log when changing the password" do
      @password.change_to_s("other", "mypass").should_not be_include("mypass")
    end

    it "should redact the password when displaying the old value" do
      @password.is_to_s("currentpassword").should =~ /^\[old password hash redacted\]$/
    end

    it "should redact the password when displaying the new value" do
      @password.should_to_s("newpassword").should =~ /^\[new password hash redacted\]$/
    end

    it "should fail if a ':' is included in the password" do
      lambda { @password.should = "some:thing" }.should raise_error(Puppet::Error)
    end

    it "should allow the value to be set to :absent" do
      lambda { @password.should = :absent }.should_not raise_error
    end
  end

  describe "when manages_solaris_rbac is enabled" do
    before do
      @provider.stubs(:satisfies?).returns(false)
      @provider.expects(:satisfies?).with([:manages_solaris_rbac]).returns(true)
    end

    it "should support a :role value for ensure" do
      @ensure = user.attrclass(:ensure).new(:resource => @resource)
      lambda { @ensure.should = :role }.should_not raise_error
    end
  end

  describe "when user has roles" do
    before do
      # To test this feature, we have to support it.
      user.new(:name => "foo").provider.class.stubs(:feature?).returns(true)
    end

    it "should autorequire roles" do
      testuser = Puppet::Type.type(:user).new(:name => "testuser")
      testuser.provider.stubs(:send).with(:roles).returns("")
      testuser[:roles] = "testrole"

      testrole = Puppet::Type.type(:user).new(:name => "testrole")

      config = Puppet::Resource::Catalog.new :testing do |conf|
        [testuser, testrole].each { |resource| conf.add_resource resource }
      end
      Puppet::Type::User::ProviderDirectoryservice.stubs(:get_macosx_version_major).returns "10.5"

      rel = testuser.autorequire[0]
      rel.source.ref.should == testrole.ref
      rel.target.ref.should == testuser.ref
    end
  end
end
