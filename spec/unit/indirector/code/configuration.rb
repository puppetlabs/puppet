#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-9-23.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/code/configuration'

describe Puppet::Indirector::Code::Configuration do
    before do
        Puppet.expects(:version).returns(1)
        Facter.expects(:value).with('fqdn').returns("my.server.com")
        Facter.expects(:value).with('ipaddress').returns("my.ip.address")
    end

    it "should gather data about itself" do
        Puppet::Indirector::Code::Configuration.new
    end

    it "should cache the server metadata and reuse it" do
        compiler = Puppet::Indirector::Code::Configuration.new
        node1 = stub 'node1', :merge => nil
        node2 = stub 'node2', :merge => nil
        compiler.stubs(:compile)
        Puppet::Node.stubs(:search).with('node1').returns(node1)
        Puppet::Node.stubs(:search).with('node2').returns(node2)

        compiler.find('node1')
        compiler.find('node2')
    end

    it "should provide a method for determining if the configuration is networked" do
        compiler = Puppet::Indirector::Code::Configuration.new
        compiler.should respond_to(:networked?)
    end
end

describe Puppet::Indirector::Code::Configuration, " when creating the interpreter" do
    before do
        # This gets pretty annoying on a plane where we have no IP address
        Facter.stubs(:value).returns("whatever")
        @compiler = Puppet::Indirector::Code::Configuration.new
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

describe Puppet::Indirector::Code::Configuration, " when finding nodes" do
    before do
        Facter.stubs(:value).returns("whatever")
        @compiler = Puppet::Indirector::Code::Configuration.new
        @name = "me"
        @node = mock 'node'
        @compiler.stubs(:compile)
    end

    it "should look node information up via the Node class with the provided key" do
        @node.stubs :merge 
        Puppet::Node.expects(:search).with(@name).returns(@node)
        @compiler.find(@name)
    end

    it "should fail if it cannot find the node" do
        @node.stubs :merge 
        Puppet::Node.expects(:search).with(@name).returns(nil)
        proc { @compiler.find(@name) }.should raise_error(Puppet::Error)
    end
end

describe Puppet::Indirector::Code::Configuration, " after finding nodes" do
    before do
        Puppet.expects(:version).returns(1)
        Puppet.settings.stubs(:value).with(:node_name).returns("cert")
        Facter.expects(:value).with('fqdn').returns("my.server.com")
        Facter.expects(:value).with('ipaddress').returns("my.ip.address")
        @compiler = Puppet::Indirector::Code::Configuration.new
        @name = "me"
        @node = mock 'node'
        @compiler.stubs(:compile)
        Puppet::Node.stubs(:search).with(@name).returns(@node)
    end

    it "should add the server's Puppet version to the node's parameters as 'serverversion'" do
        @node.expects(:merge).with { |args| args["serverversion"] == "1" }
        @compiler.find(@name)
    end

    it "should add the server's fqdn to the node's parameters as 'servername'" do
        @node.expects(:merge).with { |args| args["servername"] == "my.server.com" }
        @compiler.find(@name)
    end

    it "should add the server's IP address to the node's parameters as 'serverip'" do
        @node.expects(:merge).with { |args| args["serverip"] == "my.ip.address" }
        @compiler.find(@name)
    end

    # LAK:TODO This is going to be difficult, because this whole process is so
    # far removed from the actual connection that the certificate information
    # will be quite hard to come by, dum by, gum by.
    it "should search for the name using the client certificate's DN if the :node_name setting is set to 'cert'" do
        pending "Probably will end up in the REST work"
    end
end

describe Puppet::Indirector::Code::Configuration, " when creating configurations" do
    before do
        Facter.stubs(:value).returns("whatever")
        @compiler = Puppet::Indirector::Code::Configuration.new
        @name = "me"
        @node = Puppet::Node.new @name, :environment => "yay"
        @node.stubs(:merge)
        Puppet::Node.stubs(:search).with(@name).returns(@node)
    end

    it "should directly use provided nodes" do
        Puppet::Node.expects(:search).never
        @compiler.interpreter.expects(:compile).with(@node)
        @compiler.find(@node)
    end

    it "should pass the found node to the interpreter for compiling" do
        config = mock 'config'
        @compiler.interpreter.expects(:compile).with(@node)
        @compiler.find(@name)
    end

    it "should return the results of compiling as the configuration" do
        config = mock 'config'
        result = mock 'result', :to_transportable => :configuration

        @compiler.interpreter.expects(:compile).with(@node).returns(result)
        @compiler.find(@name).should == :configuration
    end

    it "should benchmark the compile process" do
        @compiler.stubs(:networked?).returns(true)
        @compiler.expects(:benchmark).with do |level, message|
            level == :notice and message =~ /^Compiled configuration/
        end
        @compiler.interpreter.stubs(:compile).with(@node)
        @compiler.find(@name)
    end
end

describe Puppet::Indirector::Code::Configuration, " when determining a client's available configuration version" do
    before do
        Puppet::Node::Facts.stubs(:find).returns(nil)
        Facter.stubs(:value).returns("whatever")
        @configuration = Puppet::Indirector::Code::Configuration.new
        @name = "johnny"
    end

    it "should provide a mechanism for providing the version of a given client's configuration" do
        @configuration.should respond_to(:version)
    end

    it "should use the client's Facts version as the available configuration version if it is the most recent" do
        Puppet::Node::Facts.expects(:version).with(@name).returns(5)
        Puppet::Node.expects(:version).with(@name).returns(3)
        @configuration.interpreter.stubs(:configuration_version).returns(4)

        @configuration.version(@name).should == 5
    end

    it "should use the client's Node version as the available configuration version if it is the most recent" do
        Puppet::Node::Facts.expects(:version).with(@name).returns(3)
        Puppet::Node.expects(:version).with(@name).returns(5)
        @configuration.interpreter.stubs(:configuration_version).returns(4)

        @configuration.version(@name).should == 5
    end

    it "should use the last parse date as the available configuration version if it is the most recent" do
        Puppet::Node::Facts.expects(:version).with(@name).returns(3)
        Puppet::Node.expects(:version).with(@name).returns(4)
        @configuration.interpreter.stubs(:configuration_version).returns(5)

        @configuration.version(@name).should == 5
    end

    it "should return a version of 0 if no information on the node can be found" do
        Puppet::Node.stubs(:search).returns(nil)
        @configuration.version(@name).should == 0
    end

    it "should indicate when an update is available even if an input has clock skew" do
        pending "Unclear how to implement this"
    end

    it "should not indicate an available update when apparent updates are a result of clock skew" do
        pending "Unclear how to implement this"
    end
end
