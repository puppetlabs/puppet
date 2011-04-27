#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/node/environment'

describe "Puppet::Rails::Host", :if => Puppet.features.rails? do
  def column(name, type)
    ActiveRecord::ConnectionAdapters::Column.new(name, nil, type, false)
  end

  before do
    require 'puppet/rails/host'

    # Stub this so we don't need access to the DB.
    Puppet::Rails::Host.stubs(:columns).returns([column("name", "string"), column("environment", "string"), column("ip", "string")])

    @node = Puppet::Node.new("foo")
    @node.environment = "production"
    @node.ipaddress = "127.0.0.1"

    @host = stub 'host', :environment= => nil, :ip= => nil
  end

  describe "when converting a Puppet::Node instance into a Rails instance" do
    it "should modify any existing instance in the database" do
      Puppet::Rails::Host.expects(:find_by_name).with("foo").returns @host

      Puppet::Rails::Host.from_puppet(@node)
    end

    it "should create a new instance in the database if none can be found" do
      Puppet::Rails::Host.expects(:find_by_name).with("foo").returns nil
      Puppet::Rails::Host.expects(:new).with(:name => "foo").returns @host

      Puppet::Rails::Host.from_puppet(@node)
    end

    it "should copy the environment from the Puppet instance" do
      Puppet::Rails::Host.expects(:find_by_name).with("foo").returns @host

      @node.environment = "production"
      @host.expects(:environment=).with {|x| x.name.to_s == 'production' }

      Puppet::Rails::Host.from_puppet(@node)
    end

    it "should stringify the environment" do
      host = Puppet::Rails::Host.new
      host.environment = Puppet::Node::Environment.new("production")
      host.environment.class.should == String
    end

    it "should copy the ipaddress from the Puppet instance" do
      Puppet::Rails::Host.expects(:find_by_name).with("foo").returns @host

      @node.ipaddress = "192.168.0.1"
      @host.expects(:ip=).with "192.168.0.1"

      Puppet::Rails::Host.from_puppet(@node)
    end

    it "should not save the Rails instance" do
      Puppet::Rails::Host.expects(:find_by_name).with("foo").returns @host

      @host.expects(:save).never

      Puppet::Rails::Host.from_puppet(@node)
    end
  end

  describe "when converting a Puppet::Rails::Host instance into a Puppet::Node instance" do
    before do
      @host = Puppet::Rails::Host.new(:name => "foo", :environment => "production", :ip => "127.0.0.1")
      @node = Puppet::Node.new("foo")
      Puppet::Node.stubs(:new).with("foo").returns @node
    end

    it "should create a new instance with the correct name" do
      Puppet::Node.expects(:new).with("foo").returns @node

      @host.to_puppet
    end

    it "should copy the environment from the Rails instance" do
      @host.environment = "prod"
      @node.expects(:environment=).with "prod"
      @host.to_puppet
    end

    it "should copy the ipaddress from the Rails instance" do
      @host.ip = "192.168.0.1"
      @node.expects(:ipaddress=).with "192.168.0.1"
      @host.to_puppet
    end
  end

  describe "when merging catalog resources and database resources" do
    before :each do
      Puppet.settings.stubs(:[]).with(:thin_storeconfigs).returns(false)
      @resource1 = stub_everything 'res1'
      @resource2 = stub_everything 'res2'
      @resources = [ @resource1, @resource2 ]

      @dbresource1 = stub_everything 'dbres1'
      @dbresource2 = stub_everything 'dbres2'
      @dbresources = { 1 => @dbresource1, 2 => @dbresource2 }

      @host = Puppet::Rails::Host.new(:name => "foo", :environment => "production", :ip => "127.0.0.1")
      @host.stubs(:find_resources).returns(@dbresources)
      @host.stubs(:find_resources_parameters_tags)
      @host.stubs(:compare_to_catalog)
      @host.stubs(:id).returns(1)
    end

    it "should find all database resources" do
      @host.expects(:find_resources)

      @host.merge_resources(@resources)
    end

    it "should find all paramaters and tags for those database resources" do
      @host.expects(:find_resources_parameters_tags).with(@dbresources)

      @host.merge_resources(@resources)
    end

    it "should compare all database resources to catalog" do
      @host.expects(:compare_to_catalog).with(@dbresources, @resources)

      @host.merge_resources(@resources)
    end

    it "should compare only exported resources in thin_storeconfigs mode" do
      Puppet.settings.stubs(:[]).with(:thin_storeconfigs).returns(true)
      @resource1.stubs(:exported?).returns(true)

      @host.expects(:compare_to_catalog).with(@dbresources, [ @resource1 ])

      @host.merge_resources(@resources)
    end
  end

  describe "when searching the database for host resources" do
    before :each do
      Puppet.settings.stubs(:[]).with(:thin_storeconfigs).returns(false)
      @resource1 = stub_everything 'res1', :id => 1
      @resource2 = stub_everything 'res2', :id => 2
      @resources = [ @resource1, @resource2 ]

      @dbresources = stub 'resources'
      @dbresources.stubs(:find).returns(@resources)

      @host = Puppet::Rails::Host.new(:name => "foo", :environment => "production", :ip => "127.0.0.1")
      @host.stubs(:resources).returns(@dbresources)
    end

    it "should return a hash keyed by id of all resources" do
      @host.find_resources.should == { 1 => @resource1, 2 => @resource2 }
    end

    it "should return a hash keyed by id of only exported resources in thin_storeconfigs mode" do
      Puppet.settings.stubs(:[]).with(:thin_storeconfigs).returns(true)
      @dbresources.expects(:find).with { |*h| h[1][:conditions] == { :exported => true } }.returns([])

      @host.find_resources
    end
  end
end
