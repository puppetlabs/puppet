#!/usr/bin/env rspec
require 'spec_helper'

describe "Puppet::Resource::Catalog::ActiveRecord", :if => can_use_scratch_database? do
  include PuppetSpec::Files

  require 'puppet/rails'

  before :each do
    require 'puppet/indirector/catalog/active_record'
    setup_scratch_database
  end

  let :terminus do
    Puppet::Resource::Catalog::ActiveRecord.new
  end


  it "should be a subclass of the ActiveRecord terminus class" do
    Puppet::Resource::Catalog::ActiveRecord.ancestors.should be_include(Puppet::Indirector::ActiveRecord)
  end

  it "should use Puppet::Rails::Host as its ActiveRecord model" do
    Puppet::Resource::Catalog::ActiveRecord.ar_model.should equal(Puppet::Rails::Host)
  end

  describe "when finding an instance" do
    let :request do
      stub 'request', :key => "foo", :options => {:cache_integration_hack => true}
    end

    # This hack is here because we don't want to look in the db unless we actually want
    # to look in the db, but our indirection architecture in 0.24.x isn't flexible
    # enough to tune that via configuration.
    it "should return nil unless ':cache_integration_hack' is set to true" do
      request.options[:cache_integration_hack] = false
      Puppet::Rails::Host.expects(:find_by_name).never
      terminus.find(request).should be_nil
    end

    it "should use the Hosts ActiveRecord class to find the host" do
      Puppet::Rails::Host.expects(:find_by_name).with { |key, args| key == "foo" }
      terminus.find(request)
    end

    it "should return nil if no host instance can be found" do
      Puppet::Rails::Host.expects(:find_by_name).returns nil

      terminus.find(request).should be_nil
    end

    it "should return a catalog with the same name as the host if the host can be found" do
      host = stub 'host', :name => "foo", :resources => []
      Puppet::Rails::Host.expects(:find_by_name).returns host

      result = terminus.find(request)
      result.should be_instance_of(Puppet::Resource::Catalog)
      result.name.should == "foo"
    end

    it "should set each of the host's resources as a transportable resource within the catalog" do
      host = stub 'host', :name => "foo"
      Puppet::Rails::Host.expects(:find_by_name).returns host

      res1 = mock 'res1', :to_transportable => "trans_res1"
      res2 = mock 'res2', :to_transportable => "trans_res2"

      host.expects(:resources).returns [res1, res2]

      catalog = stub 'catalog'
      Puppet::Resource::Catalog.expects(:new).returns catalog

      catalog.expects(:add_resource).with "trans_res1"
      catalog.expects(:add_resource).with "trans_res2"

      terminus.find(request)
    end
  end

  describe "when saving an instance" do
    let :catalog do Puppet::Resource::Catalog.new("foo") end
    let :request do Puppet::Indirector::Request.new(:active_record, :save, catalog) end
    let :node do Puppet::Node.new("foo", :environment => "environment") end

    before :each do
      Puppet::Node.indirection.stubs(:find).with("foo").returns(node)
    end

    it "should find the Rails host with the same name" do
      Puppet::Rails::Host.expects(:find_by_name).with("foo")
      terminus.save(request)
    end

    it "should create a new Rails host if none can be found" do
      Puppet::Rails::Host.find_by_name('foo').should be_nil
      terminus.save(request)
      Puppet::Rails::Host.find_by_name('foo').should be_valid
    end

    it "should set the catalog vertices as resources on the Rails host instance" do
      # We need to stub this so we get the same object, not just the same
      # content, otherwise the expect can't fire. :(
      host = Puppet::Rails::Host.create!(:name => "foo")
      Puppet::Rails::Host.expects(:find_by_name).with("foo").returns(host)
      catalog.expects(:vertices).returns("foo")
      host.expects(:merge_resources).with("foo")

      terminus.save(request)
    end

    it "should set host ip if we could find a matching node" do
      node.merge("ipaddress" => "192.168.0.1")
      terminus.save(request)
      Puppet::Rails::Host.find_by_name("foo").ip.should == '192.168.0.1'
    end

    it "should set host environment if we could find a matching node" do
      terminus.save(request)
      Puppet::Rails::Host.find_by_name("foo").environment.should == "environment"
    end

    it "should set the last compile time on the host" do
      now = Time.now
      terminus.save(request)
      Puppet::Rails::Host.find_by_name("foo").last_compile.should be_within(1).of(now)
    end

    it "should save the Rails host instance" do
      host = Puppet::Rails::Host.create!(:name => "foo")
      Puppet::Rails::Host.expects(:find_by_name).with("foo").returns(host)
      host.expects(:save)

      terminus.save(request)
    end
  end
end
