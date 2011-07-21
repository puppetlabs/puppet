#!/usr/bin/env rspec
require 'spec_helper'
require 'matchers/json'

describe Puppet::Node do
  describe "when managing its environment" do
    it "should use any set environment" do
      Puppet::Node.new("foo", :environment => "bar").environment.name.should == :bar
    end

    it "should support providing an actual environment instance" do
      Puppet::Node.new("foo", :environment => Puppet::Node::Environment.new(:bar)).environment.name.should == :bar
    end

    it "should determine its environment from its parameters if no environment is set" do
      Puppet::Node.new("foo", :parameters => {"environment" => :bar}).environment.name.should == :bar
    end

    it "should use the default environment if no environment is provided" do
      Puppet::Node.new("foo").environment.name.should == Puppet::Node::Environment.new.name
    end

    it "should always return an environment instance rather than a string" do
      Puppet::Node.new("foo").environment.should be_instance_of(Puppet::Node::Environment)
    end

    it "should allow the environment to be set after initialization" do
      node = Puppet::Node.new("foo")
      node.environment = :bar
      node.environment.name.should == :bar
    end

    it "should allow its environment to be set by parameters after initialization" do
      node = Puppet::Node.new("foo")
      node.parameters["environment"] = :bar
      node.environment.name.should == :bar
    end
  end
end

describe Puppet::Node, "when initializing" do
  before do
    @node = Puppet::Node.new("testnode")
  end

  it "should set the node name" do
    @node.name.should == "testnode"
  end

  it "should not allow nil node names" do
    proc { Puppet::Node.new(nil) }.should raise_error(ArgumentError)
  end

  it "should default to an empty parameter hash" do
    @node.parameters.should == {}
  end

  it "should default to an empty class array" do
    @node.classes.should == []
  end

  it "should note its creation time" do
    @node.time.should be_instance_of(Time)
  end

  it "should accept parameters passed in during initialization" do
    params = {"a" => "b"}
    @node = Puppet::Node.new("testing", :parameters => params)
    @node.parameters.should == params
  end

  it "should accept classes passed in during initialization" do
    classes = %w{one two}
    @node = Puppet::Node.new("testing", :classes => classes)
    @node.classes.should == classes
  end

  it "should always return classes as an array" do
    @node = Puppet::Node.new("testing", :classes => "myclass")
    @node.classes.should == ["myclass"]
  end
end

describe Puppet::Node, "when merging facts" do
  before do
    @node = Puppet::Node.new("testnode")
    Puppet::Node::Facts.indirection.stubs(:find).with(@node.name).returns(Puppet::Node::Facts.new(@node.name, "one" => "c", "two" => "b"))
  end

  it "should fail intelligently if it cannot find facts" do
    Puppet::Node::Facts.indirection.expects(:find).with(@node.name).raises "foo"
    lambda { @node.fact_merge }.should raise_error(Puppet::Error)
  end

  it "should prefer parameters already set on the node over facts from the node" do
    @node = Puppet::Node.new("testnode", :parameters => {"one" => "a"})
    @node.fact_merge
    @node.parameters["one"].should == "a"
  end

  it "should add passed parameters to the parameter list" do
    @node = Puppet::Node.new("testnode", :parameters => {"one" => "a"})
    @node.fact_merge
    @node.parameters["two"].should == "b"
  end

  it "should accept arbitrary parameters to merge into its parameters" do
    @node = Puppet::Node.new("testnode", :parameters => {"one" => "a"})
    @node.merge "two" => "three"
    @node.parameters["two"].should == "three"
  end

  it "should add the environment to the list of parameters" do
    Puppet.settings.stubs(:value).with(:environments).returns("one,two")
    Puppet.settings.stubs(:value).with(:environment).returns("one")
    @node = Puppet::Node.new("testnode", :environment => "one")
    @node.merge "two" => "three"
    @node.parameters["environment"].should == "one"
  end

  it "should not set the environment if it is already set in the parameters" do
    Puppet.settings.stubs(:value).with(:environments).returns("one,two")
    Puppet.settings.stubs(:value).with(:environment).returns("one")
    @node = Puppet::Node.new("testnode", :environment => "one")
    @node.merge "environment" => "two"
    @node.parameters["environment"].should == "two"
  end
end

describe Puppet::Node, "when indirecting" do
  it "should default to the 'plain' node terminus" do
    Puppet::Node.indirection.reset_terminus_class

    Puppet::Node.indirection.terminus_class.should == :plain
  end
end

describe Puppet::Node, "when generating the list of names to search through" do
  before do
    @node = Puppet::Node.new("foo.domain.com", :parameters => {"hostname" => "yay", "domain" => "domain.com"})
  end

  it "should return an array of names" do
    @node.names.should be_instance_of(Array)
  end

  describe "and the node name is fully qualified" do
    it "should contain an entry for each part of the node name" do
      @node.names.should be_include("foo.domain.com")
      @node.names.should be_include("foo.domain")
      @node.names.should be_include("foo")
    end
  end

  it "should include the node's fqdn" do
    @node.names.should be_include("yay.domain.com")
  end

  it "should combine and include the node's hostname and domain if no fqdn is available" do
    @node.names.should be_include("yay.domain.com")
  end

  it "should contain an entry for each name available by stripping a segment of the fqdn" do
    @node.parameters["fqdn"] = "foo.deep.sub.domain.com"
    @node.names.should be_include("foo.deep.sub.domain")
    @node.names.should be_include("foo.deep.sub")
  end

  describe "and :node_name is set to 'cert'" do
    before do
      Puppet.settings.stubs(:value).with(:strict_hostname_checking).returns false
      Puppet.settings.stubs(:value).with(:node_name).returns "cert"
    end

    it "should use the passed-in key as the first value" do
      @node.names[0].should == "foo.domain.com"
    end

    describe "and strict hostname checking is enabled" do
      it "should only use the passed-in key" do
        Puppet.settings.expects(:value).with(:strict_hostname_checking).returns true
        @node.names.should == ["foo.domain.com"]
      end
    end
  end

  describe "and :node_name is set to 'facter'" do
    before do
      Puppet.settings.stubs(:value).with(:strict_hostname_checking).returns false
      Puppet.settings.stubs(:value).with(:node_name).returns "facter"
    end

    it "should use the node's 'hostname' fact as the first value" do
      @node.names[0].should == "yay"
    end
  end
end
