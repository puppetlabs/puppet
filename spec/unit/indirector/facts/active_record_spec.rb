#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/rails'
require 'puppet/node/facts'

describe "Puppet::Node::Facts::ActiveRecord", :if => Puppet.features.rails? do
  before do
    require 'puppet/indirector/facts/active_record'
    Puppet.features.stubs(:rails?).returns true
    Puppet::Rails.stubs(:init)
  end

  let :terminus do
    Puppet::Node::Facts::ActiveRecord.new
  end

  it "should issue a deprecation warning" do
    Puppet.expects(:deprecation_warning).with() { |msg| msg =~ /ActiveRecord-based storeconfigs and inventory are deprecated/ }
    terminus
  end

  it "should be a subclass of the ActiveRecord terminus class" do
    Puppet::Node::Facts::ActiveRecord.ancestors.should be_include(Puppet::Indirector::ActiveRecord)
  end

  it "should use Puppet::Rails::Host as its ActiveRecord model" do
    Puppet::Node::Facts::ActiveRecord.ar_model.should equal(Puppet::Rails::Host)
  end

  describe "when finding an instance" do
    let :request do
      stub 'request', :key => "foo"
    end

    it "should use the Hosts ActiveRecord class to find the host" do
      Puppet::Rails::Host.expects(:find_by_name).with { |key, args| key == "foo" }
      terminus.find(request)
    end

    it "should include the fact names and values when finding the host" do
      Puppet::Rails::Host.expects(:find_by_name).with { |key, args| args[:include] == {:fact_values => :fact_name} }
      terminus.find(request)
    end

    it "should return nil if no host instance can be found" do
      Puppet::Rails::Host.expects(:find_by_name).returns nil
      terminus.find(request).should be_nil
    end

    it "should convert the node's parameters into a Facts instance if a host instance is found" do
      host = stub 'host', :name => "foo"
      host.expects(:get_facts_hash).returns("one" => [mock("two_value", :value => "two")], "three" => [mock("three_value", :value => "four")])

      Puppet::Rails::Host.expects(:find_by_name).returns host

      result = terminus.find(request)

      result.should be_instance_of(Puppet::Node::Facts)
      result.name.should == "foo"
      result.values.should == {"one" => "two", "three" => "four"}
    end

    it "should convert all single-member arrays into non-arrays" do
      host = stub 'host', :name => "foo"
      host.expects(:get_facts_hash).returns("one" => [mock("two_value", :value => "two")])

      Puppet::Rails::Host.expects(:find_by_name).returns host

      terminus.find(request).values["one"].should == "two"
    end
  end

  describe "when saving an instance" do
    let :facts do
      Puppet::Node::Facts.new("foo", "one" => "two", "three" => "four")
    end

    let :request do
      stub 'request', :key => "foo", :instance => facts
    end

    let :host do
      stub 'host', :name => "foo", :save => nil, :merge_facts => nil
    end

    before do
      Puppet::Rails::Host.stubs(:find_by_name).returns host
    end

    it "should find the Rails host with the same name" do
      Puppet::Rails::Host.expects(:find_by_name).with("foo").returns host
      terminus.save(request)
    end

    it "should create a new Rails host if none can be found" do
      Puppet::Rails::Host.expects(:find_by_name).with("foo").returns nil
      Puppet::Rails::Host.expects(:create).with(:name => "foo").returns host
      terminus.save(request)
    end

    it "should set the facts as facts on the Rails host instance" do
      # There is other stuff added to the hash.
      host.expects(:merge_facts).with { |args| args["one"] == "two" and args["three"] == "four" }
      terminus.save(request)
    end

    it "should save the Rails host instance" do
      host.expects(:save)
      terminus.save(request)
    end
  end
end
