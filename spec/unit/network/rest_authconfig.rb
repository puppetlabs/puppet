#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/rest_authconfig'

describe Puppet::Network::RestAuthConfig do

    DEFAULT_ACL = [
        { :acl => "~ ^\/catalog\/([^\/]+)$", :method => :find, :allow => '$1', :authenticated => true },
        # this one will allow all file access, and thus delegate
        # to fileserver.conf
        { :acl => "/file" },
        { :acl => "/certificate_revocation_list/ca", :method => :find, :authenticated => true },
        { :acl => "/report", :method => :save, :authenticated => true },
        { :acl => "/certificate/ca", :method => :find, :authenticated => false },
        { :acl => "/certificate/", :method => :find, :authenticated => false },
        { :acl => "/certificate_request", :method => [:find, :save], :authenticated => false },
    ]

    before :each do
        FileTest.stubs(:exists?).returns(true)
        File.stubs(:stat).returns(stub('stat', :ctime => :now))
        Time.stubs(:now).returns :now

        @authconfig = Puppet::Network::RestAuthConfig.new("dummy", false)
        @authconfig.stubs(:read)

        @acl = stub_everything 'rights'
        @authconfig.rights = @acl

        @request = stub 'request', :indirection_name => "path", :key => "to/resource", :ip => "127.0.0.1",
                                   :node => "me", :method => :save, :environment => :env, :authenticated => true
    end

    it "should use the puppet default rest authorization file" do
        Puppet.expects(:[]).with(:rest_authconfig).returns("dummy")

        Puppet::Network::RestAuthConfig.new(nil, false)
    end

    it "should read the config file when needed" do
        @authconfig.expects(:read)

        @authconfig.allowed?(@request)
    end

    it "should ask for authorization to the ACL subsystem" do
        @acl.expects(:fail_on_deny).with("/path/to/resource", :node => "me", :ip => "127.0.0.1", :method => :save, :environment => :env, :authenticated => true)

        @authconfig.allowed?(@request)
    end

    describe "when defining an acl with mk_acl" do
        it "should create a new right for each default acl" do
            @acl.expects(:newright).with(:path)
            @authconfig.mk_acl(:acl => :path)
        end

        it "should allow everyone for each default right" do
            @acl.expects(:allow).with(:path, "*")
            @authconfig.mk_acl(:acl => :path)
        end

        it "should restrict the ACL to a method" do
            @acl.expects(:restrict_method).with(:path, :method)
            @authconfig.mk_acl(:acl => :path, :method => :method)
        end

        it "should restrict the ACL to a specific authentication state" do
            @acl.expects(:restrict_authenticated).with(:path, :authentication)
            @authconfig.mk_acl(:acl => :path, :authenticated => :authentication)
        end
    end

    describe "when parsing the configuration file" do
        it "should check for missing ACL after reading the authconfig file" do
            File.stubs(:open)

            @authconfig.expects(:insert_default_acl)

            @authconfig.parse()
        end
    end

    DEFAULT_ACL.each do |acl|
        it "should insert #{acl[:acl]} if not present" do
            @authconfig.rights.stubs(:[]).returns(true)
            @authconfig.rights.stubs(:[]).with(acl[:acl]).returns(nil)

            @authconfig.expects(:mk_acl).with { |h| h[:acl] == acl[:acl] }

            @authconfig.insert_default_acl
        end

        it "should not insert #{acl[:acl]} if present" do
            @authconfig.rights.stubs(:[]).returns(true)
            @authconfig.rights.stubs(:[]).with(acl).returns(true)

            @authconfig.expects(:mk_acl).never

            @authconfig.insert_default_acl
        end
    end

    it "should create default ACL entries if no file have been read" do
        Puppet::Network::RestAuthConfig.any_instance.stubs(:exists?).returns(false)

        Puppet::Network::RestAuthConfig.any_instance.expects(:insert_default_acl)

        Puppet::Network::RestAuthConfig.main
    end

    describe "when adding default ACLs" do

       DEFAULT_ACL.each do |acl|
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

        it "should create a last catch-all deny all rule" do
            @authconfig.stubs(:mk_acl)
            @acl.expects(:newright).with("/")
            @authconfig.insert_default_acl
        end

        it "should create a last catch-all deny all rule for any authenticated request state" do
            @authconfig.stubs(:mk_acl)
            @acl.stubs(:newright).with("/")

            @acl.expects(:restrict_authenticated).with("/", :any)

            @authconfig.insert_default_acl
        end

    end

end
