#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/catalog/compiler'
require 'puppet/rails'

describe Puppet::Resource::Catalog::Compiler do
  before do
    Puppet::Rails.stubs(:init)
    Facter.stubs(:to_hash).returns({})
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
      Puppet[:node_terminus] = :memory
      Puppet::Node.indirection.save(Puppet::Node.new("node1"))
      Puppet::Node.indirection.save(Puppet::Node.new("node2"))

      compiler = Puppet::Resource::Catalog::Compiler.new
      compiler.stubs(:compile)

      compiler.find(Puppet::Indirector::Request.new(:catalog, :find, 'node1', nil, :node => 'node1'))
      compiler.find(Puppet::Indirector::Request.new(:catalog, :find, 'node2', nil, :node => 'node2'))
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
      @request = Puppet::Indirector::Request.new(:catalog, :find, @name, nil, :node => @name)
    end

    it "should directly use provided nodes for a local request" do
      Puppet::Node.indirection.expects(:find).never
      @compiler.expects(:compile).with(@node)
      @request.stubs(:options).returns(:use_node => @node)
      @request.stubs(:remote?).returns(false)
      @compiler.find(@request)
    end

    it "rejects a provided node if the request is remote" do
      @request.stubs(:options).returns(:use_node => @node)
      @request.stubs(:remote?).returns(true)
      expect {
        @compiler.find(@request)
      }.to raise_error Puppet::Error, /invalid option use_node/i
    end

    it "should use the authenticated node name if no request key is provided" do
      @request.stubs(:key).returns(nil)
      Puppet::Node.indirection.expects(:find).with(@name, anything).returns(@node)
      @compiler.expects(:compile).with(@node)
      @compiler.find(@request)
    end

    it "should use the provided node name by default" do
      @request.expects(:key).returns "my_node"

      Puppet::Node.indirection.expects(:find).with("my_node", anything).returns @node
      @compiler.expects(:compile).with(@node)
      @compiler.find(@request)
    end

    it "should fail if no node is passed and none can be found" do
      Puppet::Node.indirection.stubs(:find).with(@name, anything).returns(nil)
      proc { @compiler.find(@request) }.should raise_error(ArgumentError)
    end

    it "should fail intelligently when searching for a node raises an exception" do
      Puppet::Node.indirection.stubs(:find).with(@name, anything).raises "eh"
      proc { @compiler.find(@request) }.should raise_error(Puppet::Error)
    end

    it "should pass the found node to the compiler for compiling" do
      Puppet::Node.indirection.expects(:find).with(@name, anything).returns(@node)
      config = mock 'config'
      Puppet::Parser::Compiler.expects(:compile).with(@node)
      @compiler.find(@request)
    end

    it "should extract and save any facts from the request" do
      Puppet::Node.indirection.expects(:find).with(@name, anything).returns @node
      @compiler.expects(:extract_facts_from_request).with(@request)
      Puppet::Parser::Compiler.stubs(:compile)
      @compiler.find(@request)
    end

    it "requires `facts_format` option if facts are passed in" do
      facts = Puppet::Node::Facts.new("mynode", :afact => "avalue")
      request = Puppet::Indirector::Request.new(:catalog, :find, "mynode", nil, :facts => facts)
      expect {
        @compiler.find(request)
      }.to raise_error ArgumentError, /no fact format provided for mynode/
    end

    it "rejects facts in the request from a different node" do
      facts = Puppet::Node::Facts.new("differentnode", :afact => "avalue")
      request = Puppet::Indirector::Request.new(
        :catalog, :find, "mynode", nil, :facts => facts, :facts_format => "unused"
      )
      expect {
        @compiler.find(request)
      }.to raise_error Puppet::Error, /fact definition for the wrong node/i
    end

    it "should return the results of compiling as the catalog" do
      Puppet::Node.indirection.stubs(:find).returns(@node)
      config = mock 'config'
      result = mock 'result'

      Puppet::Parser::Compiler.expects(:compile).returns result
      @compiler.find(@request).should equal(result)
    end
  end

  describe "when extracting facts from the request" do
    before do
      Puppet::Node::Facts.indirection.terminus_class = :memory
      Facter.stubs(:value).returns "something"
      @compiler = Puppet::Resource::Catalog::Compiler.new

      @facts = Puppet::Node::Facts.new('hostname', "fact" => "value", "architecture" => "i386")
    end

    def a_request_that_contains(facts)
      request = Puppet::Indirector::Request.new(:catalog, :find, "hostname", nil)
      request.options[:facts_format] = "pson"
      request.options[:facts] = CGI.escape(facts.render(:pson))
      request
    end

    it "should do nothing if no facts are provided" do
      request = Puppet::Indirector::Request.new(:catalog, :find, "hostname", nil)
      request.options[:facts] = nil

      @compiler.extract_facts_from_request(request).should be_nil
    end

    it "deserializes the facts and timestamps them" do
      @facts.timestamp = Time.parse('2010-11-01')
      request = a_request_that_contains(@facts)
      now = Time.parse('2010-11-02')
      Time.stubs(:now).returns(now)

      facts = @compiler.extract_facts_from_request(request)

      facts.timestamp.should == now
    end

    it "should convert the facts into a fact instance and save it" do
      request = a_request_that_contains(@facts)

      options = {
        :environment => request.environment,
        :transaction_uuid => request.options[:transaction_uuid],
      }

      Puppet::Node::Facts.indirection.expects(:save).with(equals(@facts), nil, options)

      @compiler.extract_facts_from_request(request)
    end
  end

  describe "when finding nodes" do
    it "should look node information up via the Node class with the provided key" do
      Facter.stubs(:value).returns("whatever")
      node = Puppet::Node.new('node')
      compiler = Puppet::Resource::Catalog::Compiler.new
      request = Puppet::Indirector::Request.new(:catalog, :find, "me", nil)
      compiler.stubs(:compile)

      Puppet::Node.indirection.expects(:find).with("me", anything).returns(node)

      compiler.find(request)
    end

    it "should pass the transaction_uuid to the node indirection" do
      uuid = '793ff10d-89f8-4527-a645-3302cbc749f3'
      node = Puppet::Node.new("thing")
      compiler = Puppet::Resource::Catalog::Compiler.new
      compiler.stubs(:compile)
      request = Puppet::Indirector::Request.new(:catalog, :find, "thing",
                                                nil, :transaction_uuid => uuid)

      Puppet::Node.indirection.expects(:find).with(
        "thing",
        has_entries(:transaction_uuid => uuid)
      ).returns(node)

      compiler.find(request)
    end
  end

  describe "after finding nodes" do
    before do
      Puppet.expects(:version).returns(1)
      Facter.expects(:value).with('fqdn').returns("my.server.com")
      Facter.expects(:value).with('ipaddress').returns("my.ip.address")
      @compiler = Puppet::Resource::Catalog::Compiler.new
      @node = Puppet::Node.new("me")
      @request = Puppet::Indirector::Request.new(:catalog, :find, "me", nil)
      @compiler.stubs(:compile)
      Puppet::Node.indirection.stubs(:find).with("me", anything).returns(@node)
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
