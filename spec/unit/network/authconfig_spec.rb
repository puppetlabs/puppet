#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/network/authconfig'

describe Puppet::Network::DefaultAuthProvider do
  before :each do
    Puppet::FileSystem.stubs(:stat).returns stub('stat', :ctime => :now)
    Time.stubs(:now).returns Time.now

    Puppet::Network::DefaultAuthProvider.any_instance.stubs(:exists?).returns(true)
    # FIXME @authprovider = Puppet::Network::DefaultAuthProvider.new("dummy")
  end

  describe "when initializing" do
    it "inserts default ACLs after setting initial rights" do
      Puppet::Network::DefaultAuthProvider.any_instance.expects(:insert_default_acl)
      Puppet::Network::DefaultAuthProvider.new
    end
  end

  describe "when defining an acl with mk_acl" do
    before :each do
      Puppet::Network::DefaultAuthProvider.any_instance.stubs(:insert_default_acl)
      @authprovider = Puppet::Network::DefaultAuthProvider.new
    end

    it "should create a new right for each default acl" do
      @authprovider.mk_acl(:acl => '/')
      expect(@authprovider.rights['/']).to be
    end

    it "allows everyone for each default right" do
      @authprovider.mk_acl(:acl => '/')
      expect(@authprovider.rights['/']).to be_globalallow
    end

    it "accepts an argument to restrict the method" do
      @authprovider.mk_acl(:acl => '/', :method => :find)
      expect(@authprovider.rights['/'].methods).to eq([:find])
    end

    it "creates rights with authentication set to true by default" do
      @authprovider.mk_acl(:acl => '/')
      expect(@authprovider.rights['/'].authentication).to be_truthy
    end

    it "accepts an argument to set the authentication requirement" do
      @authprovider.mk_acl(:acl => '/', :authenticated => :any)
      expect(@authprovider.rights['/'].authentication).to be_falsey
    end
  end

  describe "when adding default ACLs" do
    before :each do
      Puppet::Network::DefaultAuthProvider.any_instance.stubs(:insert_default_acl)
      @authprovider = Puppet::Network::DefaultAuthProvider.new
      Puppet::Network::DefaultAuthProvider.any_instance.unstub(:insert_default_acl)
    end

    Puppet::Network::DefaultAuthProvider::default_acl.each do |acl|
      it "should create a default right for #{acl[:acl]}" do
        @authprovider.stubs(:mk_acl)
        @authprovider.expects(:mk_acl).with(acl)
        @authprovider.insert_default_acl
      end
    end

    it "should log at info loglevel" do
      Puppet.expects(:info).at_least_once
      @authprovider.insert_default_acl
    end

    it "creates an empty catch-all rule for '/' for any authentication request state" do
      @authprovider.stubs(:mk_acl)

      @authprovider.insert_default_acl
      expect(@authprovider.rights['/']).to be_empty
      expect(@authprovider.rights['/'].authentication).to be_falsey
    end

    it '(CVE-2013-2275) allows report submission only for the node matching the certname by default' do
      acl = {
        :acl => "~ ^#{Puppet::Network::HTTP::MASTER_URL_PREFIX}\/v3\/report\/([^\/]+)$",
        :method => :save,
        :allow => '$1',
        :authenticated => true
      }
      @authprovider.stubs(:mk_acl)
      @authprovider.expects(:mk_acl).with(acl)
      @authprovider.insert_default_acl
    end
  end

  describe "when checking authorization" do
    it "should ask for authorization to the ACL subsystem" do
      params = {
        :ip => "127.0.0.1",
        :node => "me",
        :environment => :env,
        :authenticated => true
      }

      Puppet::Network::Rights.any_instance.expects(:is_request_forbidden_and_why?).with(:save, "/path/to/resource", params)

      described_class.new.check_authorization(:save, "/path/to/resource", params)
    end
  end
end

describe Puppet::Network::AuthConfig do
  after :each do
    Puppet::Network::AuthConfig.authprovider_class = nil
  end

  class TestAuthProvider
    def initialize(rights=nil); end
    def check_authorization(method, path, params); end
  end

  it "instantiates authprovider_class with rights" do
    Puppet::Network::AuthConfig.authprovider_class = TestAuthProvider
    rights = Puppet::Network::Rights.new
    TestAuthProvider.expects(:new).with(rights)
    described_class.new(rights)
  end

  it "delegates authorization check to authprovider_class" do
    Puppet::Network::AuthConfig.authprovider_class = TestAuthProvider
    TestAuthProvider.any_instance.expects(:check_authorization).with(:save, '/path/to/resource', {})
    described_class.new.check_authorization(:save, '/path/to/resource', {})
  end

  it "uses DefaultAuthProvider by default" do
    Puppet::Network::AuthConfig.authprovider_class = nil
    Puppet::Network::DefaultAuthProvider.any_instance.expects(:check_authorization).with(:save, '/path/to/resource', {})
    described_class.new.check_authorization(:save, '/path/to/resource', {})
  end
end
