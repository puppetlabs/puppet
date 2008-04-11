#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-9-23.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/catalog/compiler'

describe Puppet::Node::Catalog::Compiler do
    before do
        Puppet.expects(:version).returns(1)
        Facter.expects(:value).with('fqdn').returns("my.server.com")
        Facter.expects(:value).with('ipaddress').returns("my.ip.address")
    end

    it "should gather data about itself" do
        Puppet::Node::Catalog::Compiler.new
    end

    it "should cache the server metadata and reuse it" do
        compiler = Puppet::Node::Catalog::Compiler.new
        node1 = stub 'node1', :merge => nil
        node2 = stub 'node2', :merge => nil
        compiler.stubs(:compile)
        Puppet::Node.stubs(:find_by_any_name).with('node1').returns(node1)
        Puppet::Node.stubs(:find_by_any_name).with('node2').returns(node2)

        compiler.find(stub('request', :key => 'node1', :options => {}))
        compiler.find(stub('node2request', :key => 'node2', :options => {}))
    end

    it "should provide a method for determining if the catalog is networked" do
        compiler = Puppet::Node::Catalog::Compiler.new
        compiler.should respond_to(:networked?)
    end
end

describe Puppet::Node::Catalog::Compiler, " when creating the interpreter" do
    before do
        # This gets pretty annoying on a plane where we have no IP address
        Facter.stubs(:value).returns("whatever")
        @compiler = Puppet::Node::Catalog::Compiler.new
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

describe Puppet::Node::Catalog::Compiler, " when finding nodes" do
    before do
        Facter.stubs(:value).returns("whatever")
        @compiler = Puppet::Node::Catalog::Compiler.new
        @name = "me"
        @node = mock 'node'
        @request = stub 'request', :key => @name, :options => {}
        @compiler.stubs(:compile)
    end

    it "should look node information up via the Node class with the provided key" do
        @node.stubs :merge 
        Puppet::Node.expects(:find_by_any_name).with(@name).returns(@node)
        @compiler.find(@request)
    end
end

describe Puppet::Node::Catalog::Compiler, " after finding nodes" do
    before do
        Puppet.expects(:version).returns(1)
        Puppet.settings.stubs(:value).with(:node_name).returns("cert")
        Facter.expects(:value).with('fqdn').returns("my.server.com")
        Facter.expects(:value).with('ipaddress').returns("my.ip.address")
        @compiler = Puppet::Node::Catalog::Compiler.new
        @name = "me"
        @node = mock 'node'
        @request = stub 'request', :key => @name, :options => {}
        @compiler.stubs(:compile)
        Puppet::Node.stubs(:find_by_any_name).with(@name).returns(@node)
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

    # LAK:TODO This is going to be difficult, because this whole process is so
    # far removed from the actual connection that the certificate information
    # will be quite hard to come by, dum by, gum by.
    it "should search for the name using the client certificate's DN if the :node_name setting is set to 'cert'" do
        pending "Probably will end up in the REST work"
    end
end

describe Puppet::Node::Catalog::Compiler, " when creating catalogs" do
    before do
        Facter.stubs(:value).returns("whatever")
        env = stub 'environment', :name => "yay"
        Puppet::Node::Environment.stubs(:new).returns(env)

        @compiler = Puppet::Node::Catalog::Compiler.new
        @name = "me"
        @node = Puppet::Node.new @name
        @node.stubs(:merge)
        @request = stub 'request', :key => @name, :options => {}
        Puppet::Node.stubs(:find_by_any_name).with(@name).returns(@node)
    end

    it "should directly use provided nodes" do
        Puppet::Node.expects(:find_by_any_name).never
        @compiler.interpreter.expects(:compile).with(@node)
        @request.stubs(:options).returns(:node => @node)
        @compiler.find(@request)
    end

    it "should fail if no node is passed and none can be found" do
        Puppet::Node.stubs(:find_by_any_name).with(@name).returns(nil)
        proc { @compiler.find(@request) }.should raise_error(ArgumentError)
    end

    it "should pass the found node to the interpreter for compiling" do
        config = mock 'config'
        @compiler.interpreter.expects(:compile).with(@node)
        @compiler.find(@request)
    end

    it "should return the results of compiling as the catalog" do
        config = mock 'config'
        result = mock 'result'

        @compiler.interpreter.expects(:compile).with(@node).returns(result)
        @compiler.find(@request).should equal(result)
    end

    it "should benchmark the compile process" do
        @compiler.stubs(:networked?).returns(true)
        @compiler.expects(:benchmark).with do |level, message|
            level == :notice and message =~ /^Compiled catalog/
        end
        @compiler.interpreter.stubs(:compile).with(@node)
        @compiler.find(@request)
    end
end
