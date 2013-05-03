#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:user) do
  before :each do
    @provider_class = described_class.provide(:simple) do
      has_features :manages_expiry, :manages_password_age, :manages_passwords, :manages_solaris_rbac
      mk_resource_methods
      def create; end
      def delete; end
      def exists?; get(:ensure) != :absent; end
      def flush; end
      def self.instances; []; end
    end
    described_class.stubs(:defaultprovider).returns @provider_class
  end

  it "should be able to create an instance" do
    described_class.new(:name => "foo").should_not be_nil
  end

  it "should have an allows_duplicates feature" do
    described_class.provider_feature(:allows_duplicates).should_not be_nil
  end

  it "should have a manages_homedir feature" do
    described_class.provider_feature(:manages_homedir).should_not be_nil
  end

  it "should have a manages_passwords feature" do
    described_class.provider_feature(:manages_passwords).should_not be_nil
  end

  it "should have a manages_solaris_rbac feature" do
    described_class.provider_feature(:manages_solaris_rbac).should_not be_nil
  end

  it "should have a manages_expiry feature" do
    described_class.provider_feature(:manages_expiry).should_not be_nil
  end

  it "should have a manages_password_age feature" do
    described_class.provider_feature(:manages_password_age).should_not be_nil
  end

  it "should have a system_users feature" do
    described_class.provider_feature(:system_users).should_not be_nil
  end

  describe :managehome do
    let (:provider) { @provider_class.new(:name => 'foo', :ensure => :absent) }
    let (:instance) { described_class.new(:name => 'foo', :provider => provider) }

    it "defaults to false" do
      instance[:managehome].should be_false
    end

    it "can be set to false" do
      instance[:managehome] = 'false'
    end

    it "cannot be set to true for a provider that does not manage homedirs" do
      provider.class.stubs(:manages_homedir?).returns false
      expect { instance[:managehome] = 'yes' }.to raise_error Puppet::Error
    end

    it "can be set to true for a provider that does manage homedirs" do
      provider.class.stubs(:manages_homedir?).returns true
      instance[:managehome] = 'yes'
    end
  end

  describe "instances" do
    it "should delegate existence questions to its provider" do
      @provider = @provider_class.new(:name => 'foo', :ensure => :absent)
      instance = described_class.new(:name => "foo", :provider => @provider)
      instance.exists?.should == false

      @provider.set(:ensure => :present)
      instance.exists?.should == true
    end
  end

  properties = [:ensure, :uid, :gid, :home, :comment, :shell, :password, :password_min_age, :password_max_age, :groups, :roles, :auths, :profiles, :project, :keys, :expiry]

  properties.each do |property|
    it "should have a #{property} property" do
      described_class.attrclass(property).ancestors.should be_include(Puppet::Property)
    end

    it "should have documentation for its #{property} property" do
      described_class.attrclass(property).doc.should be_instance_of(String)
    end
  end

  list_properties = [:groups, :roles, :auths]

  list_properties.each do |property|
    it "should have a list '#{property}'" do
      described_class.attrclass(property).ancestors.should be_include(Puppet::Property::List)
    end
  end

  it "should have an ordered list 'profiles'" do
    described_class.attrclass(:profiles).ancestors.should be_include(Puppet::Property::OrderedList)
  end

  it "should have key values 'keys'" do
    described_class.attrclass(:keys).ancestors.should be_include(Puppet::Property::KeyValue)
  end

  describe "when retrieving all current values" do
    before do
      @provider = @provider_class.new(:name => 'foo', :ensure => :present, :uid => 15, :gid => 15)
      @user = described_class.new(:name => "foo", :uid => 10, :provider => @provider)
    end

    it "should return a hash containing values for all set properties" do
      @user[:gid] = 10
      values = @user.retrieve
      [@user.property(:uid), @user.property(:gid)].each { |property| values.should be_include(property) }
    end

    it "should set all values to :absent if the user is absent" do
      @user.property(:ensure).expects(:retrieve).returns :absent
      @user.property(:uid).expects(:retrieve).never
      @user.retrieve[@user.property(:uid)].should == :absent
    end

    it "should include the result of retrieving each property's current value if the user is present" do
      @user.retrieve[@user.property(:uid)].should == 15
    end
  end

  describe "when managing the ensure property" do
    it "should support a :present value" do
      expect { described_class.new(:name => 'foo', :ensure => :present) }.to_not raise_error
    end

    it "should support an :absent value" do
      expect { described_class.new(:name => 'foo', :ensure => :absent) }.to_not raise_error
    end

    it "should call :create on the provider when asked to sync to the :present state" do
      @provider = @provider_class.new(:name => 'foo', :ensure => :absent)
      @provider.expects(:create)
      described_class.new(:name => 'foo', :ensure => :present, :provider => @provider).parameter(:ensure).sync
    end

    it "should call :delete on the provider when asked to sync to the :absent state" do
      @provider = @provider_class.new(:name => 'foo', :ensure => :present)
      @provider.expects(:delete)
      described_class.new(:name => 'foo', :ensure => :absent, :provider => @provider).parameter(:ensure).sync
    end

    describe "and determining the current state" do
      it "should return :present when the provider indicates the user exists" do
        @provider = @provider_class.new(:name => 'foo', :ensure => :present)
        described_class.new(:name => 'foo', :ensure => :absent, :provider => @provider).parameter(:ensure).retrieve.should == :present
      end

      it "should return :absent when the provider indicates the user does not exist" do
        @provider = @provider_class.new(:name => 'foo', :ensure => :absent)
        described_class.new(:name => 'foo', :ensure => :present, :provider => @provider).parameter(:ensure).retrieve.should == :absent
      end
    end
  end

  describe "when managing the uid property" do
    it "should convert number-looking strings into actual numbers" do
      described_class.new(:name => 'foo', :uid => '50')[:uid].should == 50
    end

    it "should support UIDs as numbers" do
      described_class.new(:name => 'foo', :uid => 50)[:uid].should == 50
    end

    it "should support :absent as a value" do
      described_class.new(:name => 'foo', :uid => :absent)[:uid].should == :absent
    end
  end

  describe "when managing the gid" do
    it "should support :absent as a value" do
      described_class.new(:name => 'foo', :gid => :absent)[:gid].should == :absent
    end

    it "should convert number-looking strings into actual numbers" do
      described_class.new(:name => 'foo', :gid => '50')[:gid].should == 50
    end

    it "should support GIDs specified as integers" do
      described_class.new(:name => 'foo', :gid => 50)[:gid].should == 50
    end

    it "should support groups specified by name" do
      described_class.new(:name => 'foo', :gid => 'foo')[:gid].should == 'foo'
    end

    describe "when testing whether in sync" do
      it "should return true if no 'should' values are set" do
        # this is currently not the case because gid has no default value, so we would never even
        # call insync? on that property
        if param = described_class.new(:name => 'foo').parameter(:gid)
          param.must be_safe_insync(500)
        end
      end

      it "should return true if any of the specified groups are equal to the current integer" do
        Puppet::Util.expects(:gid).with("foo").returns 300
        Puppet::Util.expects(:gid).with("bar").returns 500
        described_class.new(:name => 'baz', :gid => [ 'foo', 'bar' ]).parameter(:gid).must be_safe_insync(500)
      end

      it "should return false if none of the specified groups are equal to the current integer" do
        Puppet::Util.expects(:gid).with("foo").returns 300
        Puppet::Util.expects(:gid).with("bar").returns 500
        described_class.new(:name => 'baz', :gid => [ 'foo', 'bar' ]).parameter(:gid).must_not be_safe_insync(700)
      end
    end

    describe "when syncing" do
      it "should use the first found, specified group as the desired value and send it to the provider" do
        Puppet::Util.expects(:gid).with("foo").returns nil
        Puppet::Util.expects(:gid).with("bar").returns 500

        @provider = @provider_class.new(:name => 'foo')
        resource = described_class.new(:name => 'foo', :provider => @provider, :gid => [ 'foo', 'bar' ])

        @provider.expects(:gid=).with 500
        resource.parameter(:gid).sync
      end
    end
  end

  describe "when managing groups" do
    it "should support a singe group" do
      expect { described_class.new(:name => 'foo', :groups => 'bar') }.to_not raise_error
    end

    it "should support multiple groups as an array" do
      expect { described_class.new(:name => 'foo', :groups => [ 'bar' ]) }.to_not raise_error
      expect { described_class.new(:name => 'foo', :groups => [ 'bar', 'baz' ]) }.to_not raise_error
    end

    it "should not support a comma separated list" do
      expect { described_class.new(:name => 'foo', :groups => 'bar,baz') }.to raise_error(Puppet::Error, /Group names must be provided as an array/)
    end

    it "should not support an empty string" do
      expect { described_class.new(:name => 'foo', :groups => '') }.to raise_error(Puppet::Error, /Group names must not be empty/)
    end

    describe "when testing is in sync" do

      before :each do
        # the useradd provider uses a single string to represent groups and so does Puppet::Property::List when converting to should values
        @provider = @provider_class.new(:name => 'foo', :groups => 'a,b,e,f')
      end

      it "should not care about order" do
        @property = described_class.new(:name => 'foo', :groups => [ 'a', 'c', 'b' ]).property(:groups)
        @property.must be_safe_insync([ 'a', 'b', 'c' ])
        @property.must be_safe_insync([ 'a', 'c', 'b' ])
        @property.must be_safe_insync([ 'b', 'a', 'c' ])
        @property.must be_safe_insync([ 'b', 'c', 'a' ])
        @property.must be_safe_insync([ 'c', 'a', 'b' ])
        @property.must be_safe_insync([ 'c', 'b', 'a' ])
      end

      it "should merge current value and desired value if membership minimal" do
        @instance = described_class.new(:name => 'foo', :groups => [ 'a', 'c', 'b' ], :provider => @provider)
        @instance[:membership] = :minimum
        @instance[:groups].should == 'a,b,c,e,f'
      end

      it "should not treat a subset of groups insync if membership inclusive" do
        @instance = described_class.new(:name => 'foo', :groups => [ 'a', 'c', 'b' ], :provider => @provider)
        @instance[:membership] = :inclusive
        @instance[:groups].should == 'a,b,c'
      end
    end
  end


  describe "when managing expiry" do
    it "should fail if given an invalid date" do
      expect { described_class.new(:name => 'foo', :expiry => "200-20-20") }.to raise_error(Puppet::Error, /Expiry dates must be YYYY-MM-DD/)
    end
  end

  describe "when managing minimum password age" do
    it "should accept a negative minimum age" do
      expect { described_class.new(:name => 'foo', :password_min_age => '-1') }.to_not raise_error
    end

    it "should fail with an empty minimum age" do
      expect { described_class.new(:name => 'foo', :password_min_age => '') }.to raise_error(Puppet::Error, /minimum age must be provided as a number/)
    end
  end

  describe "when managing maximum password age" do
    it "should accept a negative maximum age" do
      expect { described_class.new(:name => 'foo', :password_max_age => '-1') }.to_not raise_error
    end

    it "should fail with an empty maximum age" do
      expect { described_class.new(:name => 'foo', :password_max_age => '') }.to raise_error(Puppet::Error, /maximum age must be provided as a number/)
    end
  end

  describe "when managing passwords" do
    before do
      @password = described_class.new(:name => 'foo', :password => 'mypass').parameter(:password)
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
      expect { described_class.new(:name => 'foo', :password => "some:thing") }.to raise_error(Puppet::Error, /Passwords cannot include ':'/)
    end

    it "should allow the value to be set to :absent" do
      expect { described_class.new(:name => 'foo', :password => :absent) }.to_not raise_error
    end
  end

  describe "when manages_solaris_rbac is enabled" do
    it "should support a :role value for ensure" do
      expect { described_class.new(:name => 'foo', :ensure => :role) }.to_not raise_error
    end
  end

  describe "when user has roles" do
    it "should autorequire roles" do
      testuser = described_class.new(:name => "testuser", :roles => ['testrole'] )
      testrole = described_class.new(:name => "testrole")

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
