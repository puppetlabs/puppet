#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/parser/loaded_code'

describe Puppet::Parser::LoadedCode do
    %w{hostclass node definition}.each do |data|
        it "should have a method for adding a #{data}" do
            Puppet::Parser::LoadedCode.new.should respond_to("add_" + data)
        end

        it "should be able to retrieve #{data} by name" do
            loader = Puppet::Parser::LoadedCode.new
            loader.send("add_" + data, "foo", "bar")
            loader.send(data, "foo").should == "bar"
        end

        it "should retrieve #{data} insensitive to case" do
            loader = Puppet::Parser::LoadedCode.new
            loader.send("add_" + data, "Foo", "bar")
            loader.send(data, "fOo").should == "bar"
        end

        it "should return nil when asked for a #{data} that has not been added" do
            Puppet::Parser::LoadedCode.new.send(data, "foo").should be_nil
        end

        it "should be able to retrieve all #{data}s" do
            plurals = { "hostclass" => "hostclasses", "node" => "nodes", "definition" => "definitions" }
            loader = Puppet::Parser::LoadedCode.new
            loader.send("add_" + data , "foo", "bar")
            loader.send(plurals[data]).should == { "foo" => "bar" }
        end
    end

    describe "when finding a qualified instance" do
        it "should return any found instance if the instance name is fully qualified" do
            loader = Puppet::Parser::LoadedCode.new
            loader.add_hostclass "foo::bar", "yay"
            loader.find("namespace", "::foo::bar", :hostclass).should == "yay"
        end

        it "should return nil if the instance name is fully qualified and no such instance exists" do
            loader = Puppet::Parser::LoadedCode.new
            loader.find("namespace", "::foo::bar", :hostclass).should be_nil
        end

        it "should return the partially qualified object if it exists in the provided namespace" do
            loader = Puppet::Parser::LoadedCode.new
            loader.add_hostclass "foo::bar::baz", "yay"
            loader.find("foo", "bar::baz", :hostclass).should == "yay"
        end

        it "should return the unqualified object if it exists in the provided namespace" do
            loader = Puppet::Parser::LoadedCode.new
            loader.add_hostclass "foo::bar", "yay"
            loader.find("foo", "bar", :hostclass).should == "yay"
        end

        it "should return the unqualified object if it exists in the parent namespace" do
            loader = Puppet::Parser::LoadedCode.new
            loader.add_hostclass "foo::bar", "yay"
            loader.find("foo::bar::baz", "bar", :hostclass).should == "yay"
        end

        it "should should return the partially qualified object if it exists in the parent namespace" do
            loader = Puppet::Parser::LoadedCode.new
            loader.add_hostclass "foo::bar::baz", "yay"
            loader.find("foo::bar", "bar::baz", :hostclass).should == "yay"
        end

        it "should return the qualified object if it exists in the root namespace" do
            loader = Puppet::Parser::LoadedCode.new
            loader.add_hostclass "foo::bar::baz", "yay"
            loader.find("foo::bar", "foo::bar::baz", :hostclass).should == "yay"
        end

        it "should return nil if the object cannot be found" do
            loader = Puppet::Parser::LoadedCode.new
            loader.add_hostclass "foo::bar::baz", "yay"
            loader.find("foo::bar", "eh", :hostclass).should be_nil
        end
    end

    it "should use the generic 'find' method with an empty namespace to find nodes" do
        loader = Puppet::Parser::LoadedCode.new
        loader.expects(:find).with("", "bar", :node)
        loader.find_node("bar")
    end

    it "should use the generic 'find' method to find hostclasses" do
        loader = Puppet::Parser::LoadedCode.new
        loader.expects(:find).with("foo", "bar", :hostclass)
        loader.find_hostclass("foo", "bar")
    end

    it "should use the generic 'find' method to find definitions" do
        loader = Puppet::Parser::LoadedCode.new
        loader.expects(:find).with("foo", "bar", :definition)
        loader.find_definition("foo", "bar")
    end

    it "should indicate whether any nodes are defined" do
        loader = Puppet::Parser::LoadedCode.new
        loader.add_node("foo", "bar")
        loader.should be_nodes
    end

    it "should indicate whether no nodes are defined" do
        Puppet::Parser::LoadedCode.new.should_not be_nodes
    end

    describe "when adding nodes" do
        it "should create an HostName if nodename is a string" do
            Puppet::Parser::AST::HostName.expects(:new).with(:value => "foo")
            loader = Puppet::Parser::LoadedCode.new
            loader.add_node("foo", "bar")
        end

        it "should not create an HostName if nodename is an HostName" do
            name = Puppet::Parser::AST::HostName.new(:value => "foo")

            Puppet::Parser::AST::HostName.expects(:new).with(:value => "foo").never

            loader = Puppet::Parser::LoadedCode.new
            loader.add_node(name, "bar")
        end
    end

    describe "when finding nodes" do
        before :each do
            @loader = Puppet::Parser::LoadedCode.new

            @nodename1 = stub 'nodename1', :is_a? => true
            @node1 = stub 'node1'
            @nodename2 = stub 'nodename2', :is_a? => true
            @node2 = stub 'node2'
        end
        it "should create an HostName if nodename is a string" do
            Puppet::Parser::AST::HostName.expects(:new).with(:value => "foo")

            @loader.node("foo")
        end

        it "should not create an HostName if nodename is an HostName" do
            name = Puppet::Parser::AST::HostName.new(:value => "foo")

            Puppet::Parser::AST::HostName.expects(:new).with(:value => "foo").never

            @loader.node(name)
        end

        it "should be able to find nobe by HostName" do
            namein = Puppet::Parser::AST::HostName.new(:value => "foo")
            nameout = Puppet::Parser::AST::HostName.new(:value => "foo")

            @loader.add_node(namein, "bar")
            @loader.node(nameout) == "bar"
        end

        it "should return the first matching regex nodename" do
            @nodename1.stubs(:regex?).returns(true)
            @nodename1.expects(:match).returns(true)
            @nodename2.stubs(:regex?).returns(false)

            @loader.add_node(@nodename1, @node1)
            @loader.add_node(@nodename2, @node2)

            @loader.node("test").should == @node1
        end

        it "should not scan non-regex node" do
            @nodename1.stubs(:regex?).returns(true)
            @nodename1.stubs(:match).returns(false)
            @nodename2.stubs(:regex?).returns(false)
            @nodename2.expects(:match).never

            @loader.add_node(@nodename1,@node1)
            @loader.add_node(@nodename2,@node2)

            @loader.node("test")
        end

        it "should prefer non-regex nodes to regex nodes" do
            @nodename1.stubs(:regex?).returns(false)
            @nodename1.expects(:match).never
            @nodename2.stubs(:regex?).returns(true)
            @nodename2.expects(:match).never

            @loader.add_node(@nodename1,@node1)
            @loader.add_node(@nodename2,@node2)

            @loader.node(@nodename1)
        end
    end
end
