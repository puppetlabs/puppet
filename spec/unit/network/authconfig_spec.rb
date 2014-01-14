#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/network/authconfig'

describe Puppet::Network::AuthConfig do
  before :each do
    Puppet::FileSystem.stubs(:stat).returns stub('stat', :ctime => :now)
    Time.stubs(:now).returns Time.now

    Puppet::Network::AuthConfig.any_instance.stubs(:exists?).returns(true)
    # FIXME @authconfig = Puppet::Network::AuthConfig.new("dummy")
  end

  describe "when initializing" do
    it "inserts default ACLs after setting initial rights" do
      Puppet::Network::AuthConfig.any_instance.expects(:insert_default_acl)
      Puppet::Network::AuthConfig.new
    end
  end

  describe "when defining an acl with mk_acl" do
    before :each do
      Puppet::Network::AuthConfig.any_instance.stubs(:insert_default_acl)
      @authconfig = Puppet::Network::AuthConfig.new
    end

    it "should create a new right for each default acl" do
      @authconfig.mk_acl(:acl => '/')
      @authconfig.rights['/'].should be
    end

    it "allows everyone for each default right" do
      @authconfig.mk_acl(:acl => '/')
      @authconfig.rights['/'].should be_globalallow
    end

    it "accepts an argument to restrict the method" do
      @authconfig.mk_acl(:acl => '/', :method => :find)
      @authconfig.rights['/'].methods.should == [:find]
    end

    it "creates rights with authentication set to true by default" do
      @authconfig.mk_acl(:acl => '/')
      @authconfig.rights['/'].authentication.should be_true
    end

    it "accepts an argument to set the authentication requirement" do
      @authconfig.mk_acl(:acl => '/', :authenticated => :any)
      @authconfig.rights['/'].authentication.should be_false
    end
  end

  describe "when adding default ACLs" do
    before :each do
      Puppet::Network::AuthConfig.any_instance.stubs(:insert_default_acl)
      @authconfig = Puppet::Network::AuthConfig.new
      Puppet::Network::AuthConfig.any_instance.unstub(:insert_default_acl)
    end

    Puppet::Network::AuthConfig::DEFAULT_ACL.each do |acl|
      it "should create a default right for #{acl[:acl]}" do
        @authconfig.stubs(:mk_acl)
        @authconfig.expects(:mk_acl).with(acl)
        @authconfig.insert_default_acl
      end
    end

    it "should log at info loglevel" do
      Puppet.expects(:info).at_least_once
      @authconfig.insert_default_acl
    end

    it "creates an empty catch-all rule for '/' for any authentication request state" do
      @authconfig.stubs(:mk_acl)

      @authconfig.insert_default_acl
      @authconfig.rights['/'].should be_empty
      @authconfig.rights['/'].authentication.should be_false
    end

    it '(CVE-2013-2275) allows report submission only for the node matching the certname by default' do
      acl = {
        :acl => "~ ^\/report\/([^\/]+)$",
        :method => :save,
        :allow => '$1',
        :authenticated => true
      }
      @authconfig.stubs(:mk_acl)
      @authconfig.expects(:mk_acl).with(acl)
      @authconfig.insert_default_acl
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
