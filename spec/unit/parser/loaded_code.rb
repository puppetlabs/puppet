#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/parser/loaded_code'
require 'puppet/parser/resource_type'

describe Puppet::Parser::LoadedCode do
    before do
        @instance = Puppet::Parser::ResourceType.new(:hostclass, "foo")
        @code = Puppet::Parser::LoadedCode.new
    end

    it "should be able to add a resource type" do
        Puppet::Parser::LoadedCode.new.should respond_to(:add)
    end

    it "should consider '<<' to be an alias to 'add' but should return self" do
        loader = Puppet::Parser::LoadedCode.new
        loader.expects(:add).with "foo"
        loader.expects(:add).with "bar"
        loader << "foo" << "bar"
    end

    it "should set itself as the code collection for added resource types" do
        loader = Puppet::Parser::LoadedCode.new

        node = Puppet::Parser::ResourceType.new(:node, "foo")

        @code.add(node)
        @code.node("foo").should equal(node)

        node.code_collection.should equal(@code)
    end

    it "should store node resource types as nodes" do
        node = Puppet::Parser::ResourceType.new(:node, "foo")

        @code.add(node)
        @code.node("foo").should equal(node)
    end

    it "should store hostclasses as hostclasses" do
        klass = Puppet::Parser::ResourceType.new(:hostclass, "foo")

        @code.add(klass)
        @code.hostclass("foo").should equal(klass)
    end

    it "should store definitions as definitions" do
        define = Puppet::Parser::ResourceType.new(:definition, "foo")

        @code.add(define)
        @code.definition("foo").should equal(define)
    end

    %w{hostclass node definition}.each do |data|
        it "should have a method for adding a #{data}" do
            Puppet::Parser::LoadedCode.new.should respond_to("add_" + data)
        end

        it "should use the name of the instance to add it" do
            loader = Puppet::Parser::LoadedCode.new
            loader.send("add_#{data}", @instance)
            loader.send(data, @instance.name).should equal(@instance)
        end

        it "should fail to add a #{data} when one already exists" do
            loader = Puppet::Parser::LoadedCode.new
            loader.add @instance
            lambda { loader.add(@instance) }.should raise_error(Puppet::ParseError)
        end

        it "should return the added #{data}" do
            loader = Puppet::Parser::LoadedCode.new

            loader.add(@instance).should equal(@instance)
        end

        it "should be able to retrieve #{data} by name" do
            loader = Puppet::Parser::LoadedCode.new
            instance = Puppet::Parser::ResourceType.new(data, "bar")
            loader.add instance
            loader.send(data, "bar").should equal(instance)
        end

        it "should retrieve #{data} insensitive to case" do
            loader = Puppet::Parser::LoadedCode.new
            instance = Puppet::Parser::ResourceType.new(data, "Bar")
            loader.add instance
            loader.send(data, "bAr").should equal(instance)
        end

        it "should return nil when asked for a #{data} that has not been added" do
            Puppet::Parser::LoadedCode.new.send(data, "foo").should be_nil
        end

        it "should be able to retrieve all #{data}s" do
            plurals = { "hostclass" => "hostclasses", "node" => "nodes", "definition" => "definitions" }
            loader = Puppet::Parser::LoadedCode.new
            instance = Puppet::Parser::ResourceType.new(data, "foo")
            loader.add instance
            loader.send(plurals[data]).should == { "foo" => instance }
        end
    end

    describe "when finding a qualified instance" do
        it "should return any found instance if the instance name is fully qualified" do
            loader = Puppet::Parser::LoadedCode.new
            instance = Puppet::Parser::ResourceType.new(:hostclass, "foo::bar")
            loader.add instance
            loader.find("namespace", "::foo::bar", :hostclass).should equal(instance)
        end

        it "should return nil if the instance name is fully qualified and no such instance exists" do
            loader = Puppet::Parser::LoadedCode.new
            loader.find("namespace", "::foo::bar", :hostclass).should be_nil
        end

        it "should return the partially qualified object if it exists in the provided namespace" do
            loader = Puppet::Parser::LoadedCode.new
            instance = Puppet::Parser::ResourceType.new(:hostclass, "foo::bar::baz")
            loader.add instance
            loader.find("foo", "bar::baz", :hostclass).should equal(instance)
        end

        it "should return the unqualified object if it exists in the provided namespace" do
            loader = Puppet::Parser::LoadedCode.new
            instance = Puppet::Parser::ResourceType.new(:hostclass, "foo::bar")
            loader.add instance
            loader.find("foo", "bar", :hostclass).should equal(instance)
        end

        it "should return the unqualified object if it exists in the parent namespace" do
            loader = Puppet::Parser::LoadedCode.new
            instance = Puppet::Parser::ResourceType.new(:hostclass, "foo::bar")
            loader.add instance
            loader.find("foo::bar::baz", "bar", :hostclass).should equal(instance)
        end

        it "should should return the partially qualified object if it exists in the parent namespace" do
            loader = Puppet::Parser::LoadedCode.new
            instance = Puppet::Parser::ResourceType.new(:hostclass, "foo::bar::baz")
            loader.add instance
            loader.find("foo::bar", "bar::baz", :hostclass).should equal(instance)
        end

        it "should return the qualified object if it exists in the root namespace" do
            loader = Puppet::Parser::LoadedCode.new
            instance = Puppet::Parser::ResourceType.new(:hostclass, "foo::bar::baz")
            loader.add instance
            loader.find("foo::bar", "foo::bar::baz", :hostclass).should equal(instance)
        end

        it "should return nil if the object cannot be found" do
            loader = Puppet::Parser::LoadedCode.new
            instance = Puppet::Parser::ResourceType.new(:hostclass, "foo::bar::baz")
            loader.add instance
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
        loader.add_node(Puppet::Parser::ResourceType.new(:node, "foo"))
        loader.should be_nodes
    end

    it "should indicate whether no nodes are defined" do
        Puppet::Parser::LoadedCode.new.should_not be_nodes
    end

    describe "when finding nodes" do
        before :each do
            @loader = Puppet::Parser::LoadedCode.new
        end

        it "should return any node whose name exactly matches the provided node name" do
            node = Puppet::Parser::ResourceType.new(:node, "foo")
            @loader << node

            @loader.node("foo").should equal(node)
        end

        it "should return the first regex node whose regex matches the provided node name" do
            node1 = Puppet::Parser::ResourceType.new(:node, /\w/)
            node2 = Puppet::Parser::ResourceType.new(:node, /\d/)
            @loader << node1 << node2

            @loader.node("foo10").should equal(node1)
        end

        it "should preferentially return a node whose name is string-equal over returning a node whose regex matches a provided name" do
            node1 = Puppet::Parser::ResourceType.new(:node, /\w/)
            node2 = Puppet::Parser::ResourceType.new(:node, "foo")
            @loader << node1 << node2

            @loader.node("foo").should equal(node2)
        end
    end
end
