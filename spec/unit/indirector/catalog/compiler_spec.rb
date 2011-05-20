#!/usr/bin/env rspec
#
#  Created by Luke Kanies on 2007-9-23.
#  Copyright (c) 2007. All rights reserved.

require 'spec_helper'

require 'puppet/indirector/catalog/compiler'
require 'puppet/rails'

describe Puppet::Resource::Catalog::Compiler do
  before do
    require 'puppet/rails'
    Puppet::Rails.stubs(:init)
    Facter.stubs(:to_hash).returns({})
    Facter.stubs(:value).returns(Facter::Util::Fact.new("something"))
  end

  describe "when initializing" do
    before do
      Puppet.expects(:version).returns(1)
      Facter.expects(:value).with('fqdn').returns("my.server.com")
      Facter.expects(:value).with('ipaddress').returns("my.ip.address")
    end

    it "should gather data about itself" do
      Puppet::Resource::Catalog::Compiler.new
    end

    it "should cache the server metadata and reuse it" do
      compiler = Puppet::Resource::Catalog::Compiler.new
      node1 = stub 'node1', :merge => nil
      node2 = stub 'node2', :merge => nil
      compiler.stubs(:compile)
      Puppet::Node.indirection.stubs(:find).with('node1').returns(node1)
      Puppet::Node.indirection.stubs(:find).with('node2').returns(node2)

      compiler.find(stub('request', :key => 'node1', :node => 'node1', :options => {}))
      compiler.find(stub('node2request', :key => 'node2', :node => 'node2', :options => {}))
    end

    it "should provide a method for determining if the catalog is networked" do
      compiler = Puppet::Resource::Catalog::Compiler.new
      compiler.should respond_to(:networked?)
    end

    describe "and storeconfigs is enabled" do
      before do
        Puppet.settings.expects(:value).with(:storeconfigs).returns true
      end

      it "should initialize Rails if it is available" do
        Puppet.features.expects(:rails?).returns true
        Puppet::Rails.expects(:init)
        Puppet::Resource::Catalog::Compiler.new
      end

      it "should fail if Rails is unavailable" do
        Puppet.features.expects(:rails?).returns false
        Puppet::Rails.expects(:init).never
        lambda { Puppet::Resource::Catalog::Compiler.new }.should raise_error(Puppet::Error)
      end
    end
  end

  describe "when finding catalogs" do
    before do
      Facter.stubs(:value).returns("whatever")

      @compiler = Puppet::Resource::Catalog::Compiler.new
      @name = "me"
      @node = Puppet::Node.new @name
      @node.stubs(:merge)
      Puppet::Node.indirection.stubs(:find).returns @node
      @request = stub 'request', :key => @name, :node => @name, :options => {}
    end

    it "should directly use provided nodes" do
      Puppet::Node.indirection.expects(:find).never
      @compiler.expects(:compile).with(@node)
      @request.stubs(:options).returns(:use_node => @node)
      @compiler.find(@request)
    end

    it "should use the authenticated node name if no request key is provided" do
      @request.stubs(:key).returns(nil)
      Puppet::Node.indirection.expects(:find).with(@name).returns(@node)
      @compiler.expects(:compile).with(@node)
      @compiler.find(@request)
    end

    it "should use the provided node name by default" do
      @request.expects(:key).returns "my_node"

      Puppet::Node.indirection.expects(:find).with("my_node").returns @node
      @compiler.expects(:compile).with(@node)
      @compiler.find(@request)
    end

    it "should fail if no node is passed and none can be found" do
      Puppet::Node.indirection.stubs(:find).with(@name).returns(nil)
      proc { @compiler.find(@request) }.should raise_error(ArgumentError)
    end

    it "should fail intelligently when searching for a node raises an exception" do
      Puppet::Node.indirection.stubs(:find).with(@name).raises "eh"
      proc { @compiler.find(@request) }.should raise_error(Puppet::Error)
    end

    it "should pass the found node to the compiler for compiling" do
      Puppet::Node.indirection.expects(:find).with(@name).returns(@node)
      config = mock 'config'
      Puppet::Parser::Compiler.expects(:compile).with(@node)
      @compiler.find(@request)
    end

    it "should extract and save any facts from the request" do
      Puppet::Node.indirection.expects(:find).with(@name).returns @node
      @compiler.expects(:extract_facts_from_request).with(@request)
      Puppet::Parser::Compiler.stubs(:compile)
      @compiler.find(@request)
    end

    it "should return the results of compiling as the catalog" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      config = mock 'config'
      result = mock 'result'

      Puppet::Parser::Compiler.expects(:compile).returns result
      @compiler.find(@request).should equal(result)
    end

    it "should benchmark the compile process" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      @compiler.stubs(:networked?).returns(true)
      @compiler.expects(:benchmark).with do |level, message|
        level == :notice and message =~ /^Compiled catalog/
      end
      Puppet::Parser::Compiler.stubs(:compile)
      @compiler.find(@request)
    end

    it "should log the benchmark result" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      @compiler.stubs(:networked?).returns(true)
      Puppet::Parser::Compiler.stubs(:compile)

      Puppet.expects(:notice).with { |msg| msg =~ /Compiled catalog/ }

      @compiler.find(@request)
    end
  end

  describe "when extracting facts from the request" do
    before do
      Facter.stubs(:value).returns "something"
      @compiler = Puppet::Resource::Catalog::Compiler.new
      @request = stub 'request', :options => {}

      @facts = Puppet::Node::Facts.new('hostname', "fact" => "value", "architecture" => "i386")
      Puppet::Node::Facts.indirection.stubs(:save).returns(nil)
    end

    it "should do nothing if no facts are provided" do
      Puppet::Node::Facts.indirection.expects(:convert_from).never
      @request.options[:facts] = nil

      @compiler.extract_facts_from_request(@request)
    end

    it "should use the Facts class to deserialize the provided facts and update the timestamp" do
      @request.options[:facts_format] = "foo"
      @request.options[:facts] = "bar"
      Puppet::Node::Facts.expects(:convert_from).returns @facts

      @facts.timestamp = Time.parse('2010-11-01')
      @now = Time.parse('2010-11-02')
      Time.expects(:now).returns(@now)

      @compiler.extract_facts_from_request(@request)
      @facts.timestamp.should == @now
    end

    it "should use the provided fact format" do
      @request.options[:facts_format] = "foo"
      @request.options[:facts] = "bar"
      Puppet::Node::Facts.expects(:convert_from).with { |format, text| format == "foo" }.returns @facts

      @compiler.extract_facts_from_request(@request)
    end

    it "should convert the facts into a fact instance and save it" do
      @request.options[:facts_format] = "foo"
      @request.options[:facts] = "bar"
      Puppet::Node::Facts.expects(:convert_from).returns @facts

      Puppet::Node::Facts.indirection.expects(:save).with(@facts)

      @compiler.extract_facts_from_request(@request)
    end
  end

  describe "when finding nodes" do
    before do
      Facter.stubs(:value).returns("whatever")
      @compiler = Puppet::Resource::Catalog::Compiler.new
      @name = "me"
      @node = mock 'node'
      @request = stub 'request', :key => @name, :options => {}
      @compiler.stubs(:compile)
    end

    it "should look node information up via the Node class with the provided key" do
      @node.stubs :merge
      Puppet::Node.indirection.expects(:find).with(@name).returns(@node)
      @compiler.find(@request)
    end
  end

  describe "after finding nodes" do
    before do
      Puppet.expects(:version).returns(1)
      Facter.expects(:value).with('fqdn').returns("my.server.com")
      Facter.expects(:value).with('ipaddress').returns("my.ip.address")
      @compiler = Puppet::Resource::Catalog::Compiler.new
      @name = "me"
      @node = mock 'node'
      @request = stub 'request', :key => @name, :options => {}
      @compiler.stubs(:compile)
      Puppet::Node.indirection.stubs(:find).with(@name).returns(@node)
    end

    it "should add the server's Puppet version to the node's parameters as 'serverversion'" do
      @node.expects(:merge).with { |args| args["serverversion"] == "1" }
      @compiler.find(@request)
    end

    it "should add the server's fqdn to the node's parameters as 'servername'" do
      @node.expects(:merge).with { |args| args["servername"] == "my.server.com" }
      @compiler.find(@request)
    end

    it "should add the server's IP address to the node's parameters as 'serverip'" do
      @node.expects(:merge).with { |args| args["serverip"] == "my.ip.address" }
      @compiler.find(@request)
    end
  end

  describe "when filtering resources" do
    before :each do
      Facter.stubs(:value)
      @compiler = Puppet::Resource::Catalog::Compiler.new
      @catalog = stub_everything 'catalog'
      @catalog.stubs(:respond_to?).with(:filter).returns(true)
    end

    it "should delegate to the catalog instance filtering" do
      @catalog.expects(:filter)
      @compiler.filter(@catalog)
    end

    it "should filter out virtual resources" do
      resource = mock 'resource', :virtual? => true
      @catalog.stubs(:filter).yields(resource)

      @compiler.filter(@catalog)
    end

    it "should return the same catalog if it doesn't support filtering" do
      @catalog.stubs(:respond_to?).with(:filter).returns(false)

      @compiler.filter(@catalog).should == @catalog
    end

    it "should return the filtered catalog" do
      catalog = stub 'filtered catalog'
      @catalog.stubs(:filter).returns(catalog)

      @compiler.filter(@catalog).should == catalog
    end

  end
end
