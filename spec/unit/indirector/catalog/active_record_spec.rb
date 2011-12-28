#!/usr/bin/env rspec
require 'spec_helper'


describe "Puppet::Resource::Catalog::ActiveRecord", :if => Puppet.features.rails? do
  require 'puppet/rails'

  before :all do
    class Tableless < ActiveRecord::Base
      def self.columns
        @columns ||= []
      end
      def self.column(name, sql_type=nil, default=nil, null=true)
        columns << ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type.to_s, null)
      end
    end

    class Host < Tableless
      column :name, :string, :null => false
      column :ip, :string
      column :environment, :string
      column :last_compile, :datetime
    end
  end

  before do
    require 'puppet/indirector/catalog/active_record'
    Puppet.features.stubs(:rails?).returns true
    Puppet::Rails.stubs(:init)
    @terminus = Puppet::Resource::Catalog::ActiveRecord.new
  end

  it "should be a subclass of the ActiveRecord terminus class" do
    Puppet::Resource::Catalog::ActiveRecord.ancestors.should be_include(Puppet::Indirector::ActiveRecord)
  end

  it "should use Puppet::Rails::Host as its ActiveRecord model" do
    Puppet::Resource::Catalog::ActiveRecord.ar_model.should equal(Puppet::Rails::Host)
  end

  describe "when finding an instance" do
    it "should return nil" do
      request = stub 'request', :key => "foo"
      @terminus.find(request).should be_nil
    end

  end

  describe "when saving an instance" do
    before do
      @host = Host.new(:name => "foo")
      @host.stubs(:merge_resources)
      @host.stubs(:save)
      @host.stubs(:railsmark).yields

      @node = Puppet::Node.new("foo", :environment => "environment")
      Puppet::Node.indirection.stubs(:find).with("foo").returns(@node)

      Puppet::Rails::Host.stubs(:find_by_name).returns @host
      @catalog = Puppet::Resource::Catalog.new("foo")
      @request = Puppet::Indirector::Request.new(:active_record, :save, @catalog)
    end

    it "should find the Rails host with the same name" do
      Puppet::Rails::Host.expects(:find_by_name).with("foo").returns @host

      @terminus.save(@request)
    end

    it "should create a new Rails host if none can be found" do
      Puppet::Rails::Host.expects(:find_by_name).with("foo").returns nil

      Puppet::Rails::Host.expects(:create).with(:name => "foo").returns @host

      @terminus.save(@request)
    end

    it "should set the catalog vertices as resources on the Rails host instance" do
      @catalog.expects(:vertices).returns "foo"
      @host.expects(:merge_resources).with("foo")

      @terminus.save(@request)
    end

    it "should set host ip if we could find a matching node" do
      @node.stubs(:parameters).returns({"ipaddress" => "192.168.0.1"})

      @terminus.save(@request)
      @host.ip.should == '192.168.0.1'
    end

    it "should set host environment if we could find a matching node" do
      @terminus.save(@request)
      @host.environment.should == "environment"
    end

    it "should set the last compile time on the host" do
      now = Time.now
      Time.expects(:now).returns now

      @terminus.save(@request)
      @host.last_compile.should == now
    end

    it "should save the Rails host instance" do
      @host.expects(:save)

      @terminus.save(@request)
    end
  end
end
