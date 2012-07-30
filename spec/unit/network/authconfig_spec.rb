#! /usr/bin/env ruby -S rspec
require 'spec_helper'

require 'puppet/network/authconfig'

describe Puppet::Network::AuthConfig do
  before :each do
    File.stubs(:stat).returns(stub('stat', :ctime => :now))
    Time.stubs(:now).returns Time.now

    Puppet::Network::AuthConfig.any_instance.stubs(:exists?).returns(true)
    @authconfig = Puppet::Network::AuthConfig.new("dummy", false)
  end

  describe "when initializing" do
    before :each do
      Puppet::Network::AuthConfig.any_instance.stubs(:read)
    end

    it "should use the authconfig default pathname if none provided" do
      path = File.expand_path('/tmp/authconfig_dummy')
      Puppet[:rest_authconfig] = path

      Puppet::Network::AuthConfig.new.file.should == path
    end

    it "should read and parse the file if parsenow is true" do
      Puppet::Network::AuthConfig.any_instance.expects(:read)

      Puppet::Network::AuthConfig.new("dummy", true)
    end
  end

  describe "when parsing authconfig file" do
    before :each do
      @fd = stub 'fd'
      @fd.expects(:each).never
      File.stubs(:open).yields(@fd)

      # For most tests inserting the default acls would just add clutter
      @authconfig.stubs(:insert_default_acl)
    end

    it "should skip comments" do
      @fd.stubs(:each_line).yields('  # comment')

      Puppet::Network::Rights.any_instance.expects(:newright).never

      @authconfig.read
    end

    it "should increment line number even on commented lines" do
      @fd.stubs(:each_line).multiple_yields('  # comment','path /')

      @authconfig.read

      @authconfig.rights['/'].line.should == 2
    end

    it "should skip blank lines" do
      @fd.stubs(:each_line).yields('  ')

      Puppet::Network::Rights.any_instance.expects(:newright).never

      @authconfig.read
    end

    it "should increment line number even on blank lines" do
      @fd.stubs(:each_line).multiple_yields('  ','path /')

      @authconfig.read

      @authconfig.rights['/'].line.should == 2
    end

    it "should not throw an error if the current path right already exist" do
      @fd.stubs(:each_line).multiple_yields('path /hello', 'path /hello')

      expect { @authconfig.read }.to_not raise_error
    end

    it "should create a new right for each found path line" do
      @fd.stubs(:each_line).multiple_yields('path /certificates')

      @authconfig.read
      @authconfig.rights['/certificates'].should be
    end

    it "should create a new right for each found regex line" do
      @fd.stubs(:each_line).multiple_yields('path ~ .rb$')

      @authconfig.read
      @authconfig.rights['.rb$'].should be
    end

    it "should strip whitespace around ACE" do
      @fd.stubs(:each_line).multiple_yields(
        'path /',
        ' allow 127.0.0.1 , 172.16.10.0  '
      )

      Puppet::Network::Rights::Right.any_instance.expects(:allow).with('127.0.0.1')
      Puppet::Network::Rights::Right.any_instance.expects(:allow).with('172.16.10.0')
      @authconfig.read
    end

    it "should allow ACE inline comments" do
      @fd.stubs(:each_line).multiple_yields('path /', ' allow 127.0.0.1 # will it work?')

      Puppet::Network::Rights::Right.any_instance.expects(:allow).with('127.0.0.1')

      @authconfig.read
    end

    it "should create an allow ACE on each subsequent allow" do
      @fd.stubs(:each_line).multiple_yields('path /', 'allow 127.0.0.1')

      Puppet::Network::Rights::Right.any_instance.expects(:allow).with('127.0.0.1')

      @authconfig.read
    end

    it "should create a deny ACE on each subsequent deny" do
      @fd.stubs(:each_line).multiple_yields('path /', 'deny 127.0.0.1')

      Puppet::Network::Rights::Right.any_instance.expects(:deny).with('127.0.0.1')

      @authconfig.read
    end

    it "should inform the current ACL if we get the 'method' directive" do
      @fd.stubs(:each_line).multiple_yields('path /certificates', 'method search,find')

      Puppet::Network::Rights::Right.any_instance.expects(:restrict_method).with('search')
      Puppet::Network::Rights::Right.any_instance.expects(:restrict_method).with('find')

      @authconfig.read
    end

    it "should inform the current ACL if we get the 'environment' directive" do
      @fd.stubs(:each_line).multiple_yields('path /certificates', 'environment production,development')

      Puppet::Network::Rights::Right.any_instance.expects(:restrict_environment).with('production')
      Puppet::Network::Rights::Right.any_instance.expects(:restrict_environment).with('development')

      @authconfig.read
    end

    it "should inform the current ACL if we get the 'auth' directive" do
      @fd.stubs(:each_line).multiple_yields('path /certificates', 'auth yes')

      Puppet::Network::Rights::Right.any_instance.expects(:restrict_authenticated).with('yes')

      @authconfig.read
    end

    it "should also allow the long form 'authenticated' directive" do
      @fd.stubs(:each_line).multiple_yields('path /certificates', 'authenticated yes')

      Puppet::Network::Rights::Right.any_instance.expects(:restrict_authenticated).with('yes')

      @authconfig.read
    end

    it "should check for missing ACL after reading the authconfig file" do
      File.stubs(:open)

      @authconfig.expects(:insert_default_acl)

      @authconfig.send :parse
    end
  end

  describe "when defining an acl with mk_acl" do
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
    it "creates default ACL entries if no file have been read" do
      Puppet::Network::AuthConfig.any_instance.stubs(:exists?).returns(false)

      Puppet::Network::AuthConfig.any_instance.expects(:insert_default_acl)

      Puppet::Network::AuthConfig.main
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
  end

  describe "when checking authorization" do
    it "should ask for authorization to the ACL subsystem" do
      params = {
        :ip => "127.0.0.1",
        :node => "me",
        :environment => :env,
        :authenticated => true
      }

      Puppet::Network::Rights.any_instance.expects(:is_request_forbidden_and_why?).with("path", :save, "to/resource", params)

      @authconfig.check_authorization("path", :save, "to/resource", params)
    end
  end
end
