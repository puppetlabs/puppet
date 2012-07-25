#! /usr/bin/env ruby -S rspec
require 'spec_helper'

require 'puppet/network/authconfig'

describe Puppet::Network::AuthConfig do
  before do
    @rights = stubs 'rights'
    Puppet::Network::Rights.stubs(:new).returns(@rights)
    @rights.stubs(:each).returns([])

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
      @rights.stubs(:include?).returns(false)
      @rights.stubs(:[])
      @authconfig.stubs(:insert_default_acl)
    end

    it "should skip comments" do
      @fd.stubs(:each_line).yields('  # comment')

      @rights.expects(:newright).never

      @authconfig.read
    end

    it "should increment line number even on commented lines" do
      @fd.stubs(:each_line).multiple_yields('  # comment','path /')

      @rights.expects(:newright).with('/', 2, 'dummy')

      @authconfig.read
    end

    it "should skip blank lines" do
      @fd.stubs(:each_line).yields('  ')

      @rights.expects(:newright).never

      @authconfig.read
    end

    it "should increment line number even on blank lines" do
      @fd.stubs(:each_line).multiple_yields('  ','path /')

      @rights.expects(:newright).with('/', 2, 'dummy')

      @authconfig.read
    end

    it "should not throw an error if the current path right already exist" do
      @fd.stubs(:each_line).yields('path /hello')

      @rights.stubs(:newright).with("/hello",1, 'dummy')
      @rights.stubs(:include?).with("/hello").returns(true)

      expect { @authconfig.read }.to_not raise_error
    end

    it "should create a new right for each found path line" do
      @fd.stubs(:each_line).multiple_yields('path /certificates')

      @rights.expects(:newright).with("/certificates", 1, 'dummy')

      @authconfig.read
    end

    it "should create a new right for each found regex line" do
      @fd.stubs(:each_line).multiple_yields('path ~ .rb$')

      @rights.expects(:newright).with("~ .rb$", 1, 'dummy')

      @authconfig.read
    end

    it "should strip whitespace around ACE" do
      acl = stub 'acl', :info

      @fd.stubs(:each_line).multiple_yields('path /', ' allow 127.0.0.1 , 172.16.10.0  ')
      @rights.stubs(:newright).with('/', 1, 'dummy').returns(acl)

      acl.expects(:allow).with('127.0.0.1')
      acl.expects(:allow).with('172.16.10.0')

      @authconfig.read
    end

    it "should allow ACE inline comments" do
      acl = stub 'acl', :info

      @fd.stubs(:each_line).multiple_yields('path /', ' allow 127.0.0.1 # will it work?')
      @rights.stubs(:newright).with('/', 1, 'dummy').returns(acl)

      acl.expects(:allow).with('127.0.0.1')

      @authconfig.read
    end

    it "should create an allow ACE on each subsequent allow" do
      acl = stub 'acl', :info

      @fd.stubs(:each_line).multiple_yields('path /', 'allow 127.0.0.1')
      @rights.stubs(:newright).with('/', 1, 'dummy').returns(acl)

      acl.expects(:allow).with('127.0.0.1')

      @authconfig.read
    end

    it "should create a deny ACE on each subsequent deny" do
      acl = stub 'acl', :info

      @fd.stubs(:each_line).multiple_yields('path /', 'deny 127.0.0.1')
      @rights.stubs(:newright).with('/', 1, 'dummy').returns(acl)

      acl.expects(:deny).with('127.0.0.1')

      @authconfig.read
    end

    it "should inform the current ACL if we get the 'method' directive" do
      acl = stub 'acl', :info

      @fd.stubs(:each_line).multiple_yields('path /certificates', 'method search,find')
      @rights.stubs(:newright).with("/certificates", 1, 'dummy').returns(acl)

      acl.expects(:restrict_method).with('search')
      acl.expects(:restrict_method).with('find')

      @authconfig.read
    end

    it "should inform the current ACL if we get the 'environment' directive" do
      acl = stub 'acl', :info

      @fd.stubs(:each_line).multiple_yields('path /certificates', 'environment production,development')
      @rights.stubs(:newright).with("/certificates", 1, 'dummy').returns(acl)

      acl.expects(:restrict_environment).with('production')
      acl.expects(:restrict_environment).with('development')

      @authconfig.read
    end

    it "should inform the current ACL if we get the 'auth' directive" do
      acl = stub 'acl', :info

      @fd.stubs(:each_line).multiple_yields('path /certificates', 'auth yes')
      @rights.stubs(:newright).with("/certificates", 1, 'dummy').returns(acl)

      acl.expects(:restrict_authenticated).with('yes')

      @authconfig.read
    end

    it "should also allow the longest 'authenticated' directive" do
      acl = stub 'acl', :info

      @fd.stubs(:each_line).multiple_yields('path /certificates', 'authenticated yes')
      @rights.stubs(:newright).with("/certificates", 1, 'dummy').returns(acl)

      acl.expects(:restrict_authenticated).with('yes')

      @authconfig.read
    end
  end
end
