#! /usr/bin/env ruby
# encoding: UTF-8
require 'spec_helper'

describe Puppet::Type.type(:user) do
  before :each do
    @provider_class = described_class.provide(:simple) do
      has_features :manages_expiry, :manages_password_age, :manages_passwords, :manages_solaris_rbac, :manages_shell
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
    expect(described_class.new(:name => "foo")).not_to be_nil
  end

  it "should have an allows_duplicates feature" do
    expect(described_class.provider_feature(:allows_duplicates)).not_to be_nil
  end

  it "should have a manages_homedir feature" do
    expect(described_class.provider_feature(:manages_homedir)).not_to be_nil
  end

  it "should have a manages_passwords feature" do
    expect(described_class.provider_feature(:manages_passwords)).not_to be_nil
  end

  it "should have a manages_solaris_rbac feature" do
    expect(described_class.provider_feature(:manages_solaris_rbac)).not_to be_nil
  end

  it "should have a manages_expiry feature" do
    expect(described_class.provider_feature(:manages_expiry)).not_to be_nil
  end

  it "should have a manages_password_age feature" do
    expect(described_class.provider_feature(:manages_password_age)).not_to be_nil
  end

  it "should have a system_users feature" do
    expect(described_class.provider_feature(:system_users)).not_to be_nil
  end

  it "should have a manages_shell feature" do
    expect(described_class.provider_feature(:manages_shell)).not_to be_nil
  end

  context "managehome" do
    let (:provider) { @provider_class.new(:name => 'foo', :ensure => :absent) }
    let (:instance) { described_class.new(:name => 'foo', :provider => provider) }

    it "defaults to false" do
      expect(instance[:managehome]).to be_falsey
    end

    it "can be set to false" do
      instance[:managehome] = 'false'
    end

    it "cannot be set to true for a provider that does not manage homedirs" do
      provider.class.stubs(:manages_homedir?).returns false
      expect { instance[:managehome] = 'yes' }.to raise_error(Puppet::Error, /can not manage home directories/)
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
      expect(instance.exists?).to eq(false)

      @provider.set(:ensure => :present)
      expect(instance.exists?).to eq(true)
    end
  end

  properties = [:ensure, :uid, :gid, :home, :comment, :shell, :password, :password_min_age, :password_max_age, :password_warn_days, :groups, :roles, :auths, :profiles, :project, :keys, :expiry]

  properties.each do |property|
    it "should have a #{property} property" do
      expect(described_class.attrclass(property).ancestors).to be_include(Puppet::Property)
    end

    it "should have documentation for its #{property} property" do
      expect(described_class.attrclass(property).doc).to be_instance_of(String)
    end
  end

  list_properties = [:groups, :roles, :auths]

  list_properties.each do |property|
    it "should have a list '#{property}'" do
      expect(described_class.attrclass(property).ancestors).to be_include(Puppet::Property::List)
    end
  end

  it "should have an ordered list 'profiles'" do
    expect(described_class.attrclass(:profiles).ancestors).to be_include(Puppet::Property::OrderedList)
  end

  it "should have key values 'keys'" do
    expect(described_class.attrclass(:keys).ancestors).to be_include(Puppet::Property::KeyValue)
  end

  describe "when retrieving all current values" do
    before do
      @provider = @provider_class.new(:name => 'foo', :ensure => :present, :uid => 15, :gid => 15)
      @user = described_class.new(:name => "foo", :uid => 10, :provider => @provider)
    end

    it "should return a hash containing values for all set properties" do
      @user[:gid] = 10
      values = @user.retrieve
      [@user.property(:uid), @user.property(:gid)].each { |property| expect(values).to be_include(property) }
    end

    it "should set all values to :absent if the user is absent" do
      @user.property(:ensure).expects(:retrieve).returns :absent
      @user.property(:uid).expects(:retrieve).never
      expect(@user.retrieve[@user.property(:uid)]).to eq(:absent)
    end

    it "should include the result of retrieving each property's current value if the user is present" do
      expect(@user.retrieve[@user.property(:uid)]).to eq(15)
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
        expect(described_class.new(:name => 'foo', :ensure => :absent, :provider => @provider).parameter(:ensure).retrieve).to eq(:present)
      end

      it "should return :absent when the provider indicates the user does not exist" do
        @provider = @provider_class.new(:name => 'foo', :ensure => :absent)
        expect(described_class.new(:name => 'foo', :ensure => :present, :provider => @provider).parameter(:ensure).retrieve).to eq(:absent)
      end
    end
  end

  describe "when managing the uid property" do
    it "should convert number-looking strings into actual numbers" do
      expect(described_class.new(:name => 'foo', :uid => '50')[:uid]).to eq(50)
    end

    it "should support UIDs as numbers" do
      expect(described_class.new(:name => 'foo', :uid => 50)[:uid]).to eq(50)
    end

    it "should support :absent as a value" do
      expect(described_class.new(:name => 'foo', :uid => :absent)[:uid]).to eq(:absent)
    end
  end

  describe "when managing the gid" do
    it "should support :absent as a value" do
      expect(described_class.new(:name => 'foo', :gid => :absent)[:gid]).to eq(:absent)
    end

    it "should convert number-looking strings into actual numbers" do
      expect(described_class.new(:name => 'foo', :gid => '50')[:gid]).to eq(50)
    end

    it "should support GIDs specified as integers" do
      expect(described_class.new(:name => 'foo', :gid => 50)[:gid]).to eq(50)
    end

    it "should support groups specified by name" do
      expect(described_class.new(:name => 'foo', :gid => 'foo')[:gid]).to eq('foo')
    end

    describe "when testing whether in sync" do
      it "should return true if no 'should' values are set" do
        # this is currently not the case because gid has no default value, so we would never even
        # call insync? on that property
        if param = described_class.new(:name => 'foo').parameter(:gid)
          expect(param).to be_safe_insync(500)
        end
      end

      it "should return true if any of the specified groups are equal to the current integer" do
        Puppet::Util.expects(:gid).with("foo").returns 300
        Puppet::Util.expects(:gid).with("bar").returns 500
        expect(described_class.new(:name => 'baz', :gid => [ 'foo', 'bar' ]).parameter(:gid)).to be_safe_insync(500)
      end

      it "should return false if none of the specified groups are equal to the current integer" do
        Puppet::Util.expects(:gid).with("foo").returns 300
        Puppet::Util.expects(:gid).with("bar").returns 500
        expect(described_class.new(:name => 'baz', :gid => [ 'foo', 'bar' ]).parameter(:gid)).to_not be_safe_insync(700)
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
        expect(@property).to be_safe_insync([ 'a', 'b', 'c' ])
        expect(@property).to be_safe_insync([ 'a', 'c', 'b' ])
        expect(@property).to be_safe_insync([ 'b', 'a', 'c' ])
        expect(@property).to be_safe_insync([ 'b', 'c', 'a' ])
        expect(@property).to be_safe_insync([ 'c', 'a', 'b' ])
        expect(@property).to be_safe_insync([ 'c', 'b', 'a' ])
      end

      it "should merge current value and desired value if membership minimal" do
        @instance = described_class.new(:name => 'foo', :groups => [ 'a', 'c', 'b' ], :provider => @provider)
        @instance[:membership] = :minimum
        expect(@instance[:groups]).to eq('a,b,c,e,f')
      end

      it "should not treat a subset of groups insync if membership inclusive" do
        @instance = described_class.new(:name => 'foo', :groups => [ 'a', 'c', 'b' ], :provider => @provider)
        @instance[:membership] = :inclusive
        expect(@instance[:groups]).to eq('a,b,c')
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

  describe "when managing warning password days" do
    it "should accept a negative warning days" do
      expect { described_class.new(:name => 'foo', :password_warn_days => '-1') }.to_not raise_error
    end

    it "should fail with an empty warning days" do
      expect { described_class.new(:name => 'foo', :password_warn_days => '') }.to raise_error(Puppet::Error, /warning days must be provided as a number/)
    end
  end

  describe "when managing passwords" do
    let(:transaction) { Puppet::Transaction.new(Puppet::Resource::Catalog.new, nil, nil) }
    let(:harness) { Puppet::Transaction::ResourceHarness.new(transaction) }
    let(:provider) { @provider_class.new(:name => 'foo', :ensure => :present) }
    let(:resource) { described_class.new(:name => 'foo', :ensure => :present, :password => 'top secret', :provider => provider) }

    it "should not include the password in the change log when adding the password" do
      status = harness.evaluate(resource)
      sync_event = status.events[0]
      expect(sync_event.message).not_to include('top secret')
      expect(sync_event.message).to eql('changed [redacted] to [redacted]')
    end

    it "should not include the password in the change log when changing the password" do
      resource[:password] = 'super extra classified'
      status = harness.evaluate(resource)
      sync_event = status.events[0]
      expect(sync_event.message).not_to include('super extra classified')
      expect(sync_event.message).to eql('changed [redacted] to [redacted]')
    end

    it "should fail if a ':' is included in the password" do
      expect { described_class.new(:name => 'foo', :password => "some:thing") }.to raise_error(Puppet::Error, /Passwords cannot include ':'/)
    end

    it "should allow the value to be set to :absent" do
      expect { described_class.new(:name => 'foo', :password => :absent) }.to_not raise_error
    end
  end

  describe "when managing comment" do
    before :each do
      @value = 'abcd™'
      expect(@value.encoding).to eq(Encoding::UTF_8)
      @user = described_class.new(:name => 'foo', :comment => @value)
    end

    describe "#insync" do
      it "should delegate to the provider's #comments_insync? method if defined" do
        # useradd subclasses nameservice and thus inherits #comments_insync?
        user = described_class.new(:name => 'foo', :comment => @value, :provider => :useradd)
        comment_property = user.properties.find {|p| p.name == :comment}
        user.provider.expects(:comments_insync?)
        comment_property.insync?('bar')
      end

      describe "#change_to_s" do
        let(:is) { "\u2603" }
        let(:should) { "\u06FF" }
        let(:comment_property) { @user.properties.find { |p| p.name == :comment } }
        context "given is and should strings with incompatible encoding" do
          it "should return a formatted string" do
            is.force_encoding(Encoding::ASCII_8BIT)
            should.force_encoding(Encoding::UTF_8)
            expect(Encoding.compatible?(is, should)).to be_falsey
            expect(comment_property.change_to_s(is,should)).to match(/changed '\u{E2}\u{98}\u{83}' to '\u{DB}\u{BF}'/)
          end
        end

        context "given is and should strings with compatible encoding" do
          it "should return a formatted string" do
            is.force_encoding(Encoding::UTF_8)
            should.force_encoding(Encoding::UTF_8)
            expect(Encoding.compatible?(is, should)).to be_truthy
            expect(comment_property.change_to_s(is,should)).to match(/changed '\u{2603}' to '\u{6FF}'/u)
          end
        end
      end
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

      Puppet::Resource::Catalog.new :testing do |conf|
        [testuser, testrole].each { |resource| conf.add_resource resource }
      end
      Puppet::Type::User::ProviderDirectoryservice.stubs(:get_macosx_version_major).returns "10.5"

      rel = testuser.autorequire[0]
      expect(rel.source.ref).to eq(testrole.ref)
      expect(rel.target.ref).to eq(testuser.ref)
    end
  end

  describe "when setting shell" do
    before :each do
      @shell_provider_class = described_class.provide(:shell_manager) do
        has_features :manages_shell
        mk_resource_methods
        def create; check_valid_shell;end
        def shell=(value); check_valid_shell; end
        def delete; end
        def exists?; get(:ensure) != :absent; end
        def flush; end
        def self.instances; []; end
        def check_valid_shell; end
      end

      described_class.stubs(:defaultprovider).returns @shell_provider_class
    end

    it "should call :check_valid_shell on the provider when changing shell value" do
      @provider = @shell_provider_class.new(:name => 'foo', :shell => '/bin/bash', :ensure => :present)
      @provider.expects(:check_valid_shell)
      resource = described_class.new(:name => 'foo', :shell => '/bin/zsh', :provider => @provider)
      Puppet::Util::Storage.stubs(:load)
      Puppet::Util::Storage.stubs(:store)
      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource resource
      catalog.apply
    end

    it "should call :check_valid_shell on the provider when changing ensure from present to absent" do
      @provider = @shell_provider_class.new(:name => 'foo', :shell => '/bin/bash', :ensure => :absent)
      @provider.expects(:check_valid_shell)
      resource = described_class.new(:name => 'foo', :shell => '/bin/zsh', :provider => @provider)
      Puppet::Util::Storage.stubs(:load)
      Puppet::Util::Storage.stubs(:store)
      catalog = Puppet::Resource::Catalog.new
      catalog.add_resource resource
      catalog.apply
    end
  end

  describe "when purging ssh keys" do
    it "should not accept a keyfile with a relative path" do
      expect {
        described_class.new(:name => "a", :purge_ssh_keys => "keys")
      }.to raise_error(Puppet::Error, /Paths to keyfiles must be absolute, not keys/)
    end

    context "with a home directory specified" do
      it "should accept true" do
        described_class.new(:name => "a", :home => "/tmp", :purge_ssh_keys => true)
      end
      it "should accept the ~ wildcard" do
        described_class.new(:name => "a", :home => "/tmp", :purge_ssh_keys => "~/keys")
      end
      it "should accept the %h wildcard" do
        described_class.new(:name => "a", :home => "/tmp", :purge_ssh_keys => "%h/keys")
      end
      it "raises when given a relative path" do
        expect {
          described_class.new(:name => "a", :home => "/tmp", :purge_ssh_keys => "keys")
        }.to raise_error(Puppet::Error, /Paths to keyfiles must be absolute/)
      end
    end

    context "with no home directory specified" do
      it "should not accept true" do
        expect {
          described_class.new(:name => "a", :purge_ssh_keys => true)
        }.to raise_error(Puppet::Error, /purge_ssh_keys can only be true for users with a defined home directory/)
      end
      it "should not accept the ~ wildcard" do
        expect {
          described_class.new(:name => "a", :purge_ssh_keys => "~/keys")
        }.to raise_error(Puppet::Error, /meta character ~ or %h only allowed for users with a defined home directory/)
      end
      it "should not accept the %h wildcard" do
        expect {
          described_class.new(:name => "a", :purge_ssh_keys => "%h/keys")
        }.to raise_error(Puppet::Error, /meta character ~ or %h only allowed for users with a defined home directory/)
      end
    end

    context "with a valid parameter" do
      let(:paths) do
        [ "/dev/null", "/tmp/keyfile" ].map { |path| File.expand_path(path) }
      end
      subject do
        res = described_class.new(:name => "test", :purge_ssh_keys => paths)
        res.catalog = Puppet::Resource::Catalog.new
        res
      end
      it "should not just return from generate" do
        subject.expects :find_unmanaged_keys
        subject.generate
      end
      it "should check each keyfile for readability" do
        paths.each do |path|
          File.expects(:readable?).with(path)
        end
        subject.generate
      end
    end

    describe "generated keys" do
      subject do
        res = described_class.new(:name => "test_user_name", :purge_ssh_keys => purge_param)
        res.catalog = Puppet::Resource::Catalog.new
        res
      end
      context "when purging is disabled" do
        let(:purge_param) { false }
        its(:generate) { should be_empty }
      end
      context "when purging is enabled" do
        let(:purge_param) { my_fixture('authorized_keys') }
        let(:resources) { subject.generate }
        it "should contain a resource for each key" do
          names = resources.collect { |res| res.name }
          expect(names).to include("key1 name")
          expect(names).to include("keyname2")
        end
        it "should not include keys in comment lines" do
          names = resources.collect { |res| res.name }
          expect(names).not_to include("keyname3")
        end
        it "should generate names for unnamed keys" do
          names = resources.collect { |res| res.name }
          fixture_path = File.join(my_fixture_dir, 'authorized_keys')
          expect(names).to include("#{fixture_path}:unnamed-1")
        end
        it "should each have a value for the user property" do
          expect(resources.map { |res|
            res[:user]
          }.reject { |user_name|
            user_name == "test_user_name"
          }).to be_empty
        end
      end
    end
  end
end
