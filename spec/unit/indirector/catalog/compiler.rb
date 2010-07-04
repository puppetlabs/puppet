#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-9-23.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/catalog/compiler'

describe Puppet::Resource::Catalog::Compiler do
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
            Puppet::Node.stubs(:find).with('node1').returns(node1)
            Puppet::Node.stubs(:find).with('node2').returns(node2)

            compiler.find(stub('request', :node => 'node1', :options => {}))
            compiler.find(stub('node2request', :node => 'node2', :options => {}))
        end

        it "should provide a method for determining if the catalog is networked" do
            compiler = Puppet::Resource::Catalog::Compiler.new
            compiler.should respond_to(:networked?)
        end
    end

    describe "when creating the interpreter" do
        before do
            # This gets pretty annoying on a plane where we have no IP address
            Facter.stubs(:value).returns("whatever")
            @compiler = Puppet::Resource::Catalog::Compiler.new
        end

        it "should not create the interpreter until it is asked for the first time" do
            interp = mock 'interp'
            Puppet::Parser::Interpreter.expects(:new).with().returns(interp)
            @compiler.interpreter.should equal(interp)
        end

        it "should use the same interpreter for all compiles" do
            interp = mock 'interp'
            Puppet::Parser::Interpreter.expects(:new).with().returns(interp)
            @compiler.interpreter.should equal(interp)
            @compiler.interpreter.should equal(interp)
        end
    end

    describe "when finding catalogs" do
        before do
            Facter.stubs(:value).returns("whatever")
            env = stub 'environment', :name => "yay", :modulepath => []
            Puppet::Node::Environment.stubs(:new).returns(env)

            @compiler = Puppet::Resource::Catalog::Compiler.new
            @name = "me"
            @node = Puppet::Node.new @name
            @node.stubs(:merge)
            @request = stub 'request', :key => "does not matter", :node => @name, :options => {}
        end

        it "should directly use provided nodes" do
            Puppet::Node.expects(:find).never
            @compiler.expects(:compile).with(@node)
            @request.stubs(:options).returns(:use_node => @node)
            @compiler.find(@request)
        end

        it "should use the request's node name if no explicit node is provided" do
            Puppet::Node.expects(:find).with(@name).returns(@node)
            @compiler.expects(:compile).with(@node)
            @compiler.find(@request)
        end

        it "should use the provided node name if no explicit node is provided and no authenticated node information is available" do
            @request.expects(:node).returns nil
            @request.expects(:key).returns "my_node"

            Puppet::Node.expects(:find).with("my_node").returns @node
            @compiler.expects(:compile).with(@node)
            @compiler.find(@request)
        end

        it "should fail if no node is passed and none can be found" do
            Puppet::Node.stubs(:find).with(@name).returns(nil)
            proc { @compiler.find(@request) }.should raise_error(ArgumentError)
        end

        it "should fail intelligently when searching for a node raises an exception" do
            Puppet::Node.stubs(:find).with(@name).raises "eh"
            proc { @compiler.find(@request) }.should raise_error(Puppet::Error)
        end

        it "should pass the found node to the interpreter for compiling" do
            Puppet::Node.expects(:find).with(@name).returns(@node)
            config = mock 'config'
            @compiler.interpreter.expects(:compile).with(@node)
            @compiler.find(@request)
        end

        it "should extract and save any facts from the request" do
            Puppet::Node.expects(:find).with(@name).returns @node
            @compiler.expects(:extract_facts_from_request).with(@request)
            @compiler.interpreter.stubs(:compile)
            @compiler.find(@request)
        end

        it "should return the results of compiling as the catalog" do
            Puppet::Node.stubs(:find).returns(@node)
            config = mock 'config'
            result = mock 'result'

            @compiler.interpreter.expects(:compile).with(@node).returns(result)
            @compiler.find(@request).should equal(result)
        end

        it "should benchmark the compile process" do
            Puppet::Node.stubs(:find).returns(@node)
            @compiler.stubs(:networked?).returns(true)
            @compiler.expects(:benchmark).with do |level, message|
                level == :notice and message =~ /^Compiled catalog/
            end
            @compiler.interpreter.stubs(:compile).with(@node)
            @compiler.find(@request)
        end
    end

    describe "when extracting facts from the request" do
        before do
            @compiler = Puppet::Resource::Catalog::Compiler.new
            @request = stub 'request', :options => {}

            @facts = stub 'facts', :save => nil
        end

        it "should do nothing if no facts are provided" do
            Puppet::Node::Facts.expects(:convert_from).never
            @request.options[:facts] = nil

            @compiler.extract_facts_from_request(@request)
        end

        it "should use the Facts class to deserialize the provided facts" do
            @request.options[:facts_format] = "foo"
            @request.options[:facts] = "bar"
            Puppet::Node::Facts.expects(:convert_from).returns @facts

            @compiler.extract_facts_from_request(@request)
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

            @facts.expects(:save)

            @compiler.extract_facts_from_request(@request)
        end
    end

    describe "when finding nodes" do
        before do
            Facter.stubs(:value).returns("whatever")
            @compiler = Puppet::Resource::Catalog::Compiler.new
            @name = "me"
            @node = mock 'node'
            @request = stub 'request', :node => @name, :options => {}
            @compiler.stubs(:compile)
        end

        it "should look node information up via the Node class with the provided key" do
            @node.stubs :merge
            Puppet::Node.expects(:find).with(@name).returns(@node)
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
            @request = stub 'request', :node => @name, :options => {}
            @compiler.stubs(:compile)
            Puppet::Node.stubs(:find).with(@name).returns(@node)
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
