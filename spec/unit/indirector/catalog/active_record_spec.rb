#! /usr/bin/env ruby
require 'spec_helper'

describe "Puppet::Resource::Catalog::ActiveRecord", :if => can_use_scratch_database? do
  include PuppetSpec::Files

  before :each do
    require 'puppet/indirector/catalog/active_record'
    setup_scratch_database
  end

  after :each do
    Puppet::Rails.teardown
  end

  let :terminus do
    Puppet::Resource::Catalog::ActiveRecord.new
  end

  it "should issue a deprecation warning" do
    Puppet.expects(:deprecation_warning).with() { |msg| msg =~ /ActiveRecord-based storeconfigs and inventory are deprecated/ }

    Puppet::Resource::Catalog::ActiveRecord.new
  end

  it "should be a subclass of the ActiveRecord terminus class" do
    Puppet::Resource::Catalog::ActiveRecord.ancestors.should be_include(Puppet::Indirector::ActiveRecord)
  end

  it "should use Puppet::Rails::Host as its ActiveRecord model" do
    Puppet::Resource::Catalog::ActiveRecord.ar_model.should equal(Puppet::Rails::Host)
  end

  describe "when finding an instance" do
    it "should return nil" do
      r = stub 'request', :key => "foo", :options => {:cache_integration_hack => false}
      terminus.find(r).should be_nil
    end

    # This used to make things go to the database, but that is code that is as
    # dead as a doornail.  This just checks we don't blow up unexpectedly, and
    # can go away after a few releases. --daniel 2012-02-27
    it "should always return nil" do
      r = stub 'request', :key => "foo", :options => {:cache_integration_hack => true}
      terminus.find(r).should be_nil
    end
  end

  describe "when saving an instance" do
    let :catalog do Puppet::Resource::Catalog.new("foo") end
    let :request do Puppet::Indirector::Request.new(:active_record, :save, nil, catalog) end
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
      before = Time.now
      terminus.save(request)
      after = Time.now

      Puppet::Rails::Host.find_by_name("foo").last_compile.should be_between(before, after)
    end

    it "should save the Rails host instance" do
      host = Puppet::Rails::Host.create!(:name => "foo")
      Puppet::Rails::Host.expects(:find_by_name).with("foo").returns(host)
      host.expects(:save)

      terminus.save(request)
    end
  end
end
