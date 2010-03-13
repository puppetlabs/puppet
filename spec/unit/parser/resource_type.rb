#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/parser/resource_type'

describe Puppet::Parser::ResourceType do
    it "should have a 'name' attribute" do
        Puppet::Parser::ResourceType.new(:hostclass, "foo").name.should == "foo"
    end

    [:code, :doc, :line, :file, :code_collection].each do |attr|
        it "should have a '#{attr}' attribute" do
            type = Puppet::Parser::ResourceType.new(:hostclass, "foo")
            type.send(attr.to_s + "=", "yay")
            type.send(attr).should == "yay"
        end
    end

    describe "when a node"  do
        it "should allow a regex as its name" do
            lambda { Puppet::Parser::ResourceType.new(:node, /foo/) }.should_not raise_error
        end

        it "should allow a AST::HostName instance as its name" do
            regex = Puppet::Parser::AST::Regex.new(:value => /foo/)
            name = Puppet::Parser::AST::HostName.new(:value => regex)
            lambda { Puppet::Parser::ResourceType.new(:node, name) }.should_not raise_error
        end

        it "should match against the regexp in the AST::HostName when a HostName instance is provided" do
            regex = Puppet::Parser::AST::Regex.new(:value => /\w/)
            name = Puppet::Parser::AST::HostName.new(:value => regex)
            node = Puppet::Parser::ResourceType.new(:node, name)

            node.match("foo").should be_true
        end

        it "should return the value of the hostname if provided a string-form AST::HostName instance as the name" do
            name = Puppet::Parser::AST::HostName.new(:value => "foo")
            node = Puppet::Parser::ResourceType.new(:node, name)

            node.name.should == "foo"
        end

        describe "and the name is a regex" do
            it "should have a method that indicates that this is the case" do
                Puppet::Parser::ResourceType.new(:node, /w/).should be_name_is_regex
            end

            it "should set its namespace to ''" do
                Puppet::Parser::ResourceType.new(:node, /w/).namespace.should == ""
            end

            it "should return the regex converted to a string when asked for its name" do
                Puppet::Parser::ResourceType.new(:node, /ww/).name.should == "ww"
            end

            it "should downcase the regex when returning the name as a string" do
                Puppet::Parser::ResourceType.new(:node, /W/).name.should == "w"
            end

            it "should remove non-alpha characters when returning the name as a string" do
                Puppet::Parser::ResourceType.new(:node, /w*w/).name.should_not include("*")
            end

            it "should remove leading dots when returning the name as a string" do
                Puppet::Parser::ResourceType.new(:node, /.ww/).name.should_not =~ /^\./
            end

            it "should have a method for matching its regex name against a provided name" do
                Puppet::Parser::ResourceType.new(:node, /.ww/).should respond_to(:match)
            end

            it "should return true when its regex matches the provided name" do
                Puppet::Parser::ResourceType.new(:node, /\w/).match("foo").should be_true
            end

            it "should return false when its regex does not match the provided name" do
                (!!Puppet::Parser::ResourceType.new(:node, /\d/).match("foo")).should be_false
            end

            it "should return true when its name, as a string, is matched against an equal string" do
                Puppet::Parser::ResourceType.new(:node, "foo").match("foo").should be_true
            end

            it "should return false when its name is matched against an unequal string" do
                Puppet::Parser::ResourceType.new(:node, "foo").match("bar").should be_false
            end

            it "should match names insensitive to case" do
                Puppet::Parser::ResourceType.new(:node, "fOo").match("foO").should be_true
            end
        end

        it "should return the name converted to a string when the name is not a regex" do
            pending "Need to define LoadedCode behaviour first"
            name = Puppet::Parser::AST::HostName.new(:value => "foo")
            Puppet::Parser::ResourceType.new(:node, name).name.should == "foo"
        end

        it "should return the name converted to a string when the name is a regex" do
            pending "Need to define LoadedCode behaviour first"
            name = Puppet::Parser::AST::HostName.new(:value => /regex/)
            Puppet::Parser::ResourceType.new(:node, name).name.should == /regex/.to_s
        end

        it "should mark any created scopes as a node scope" do
            pending "Need to define LoadedCode behaviour first"
            name = Puppet::Parser::AST::HostName.new(:value => /regex/)
            Puppet::Parser::ResourceType.new(:node, name).name.should == /regex/.to_s
        end
    end

    describe "when initializing" do
        it "should require a resource super type" do
            Puppet::Parser::ResourceType.new(:hostclass, "foo").type.should == :hostclass
        end

        it "should fail if provided an invalid resource super type" do
            lambda { Puppet::Parser::ResourceType.new(:nope, "foo") }.should raise_error(ArgumentError)
        end

        it "should set its name to the downcased, stringified provided name" do
            Puppet::Parser::ResourceType.new(:hostclass, "Foo::Bar".intern).name.should == "foo::bar"
        end

        it "should set its namespace to the downcased, stringified qualified portion of the name" do
            Puppet::Parser::ResourceType.new(:hostclass, "Foo::Bar::Baz".intern).namespace.should == "foo::bar"
        end

        %w{code line file doc}.each do |arg|
            it "should set #{arg} if provided" do
                type = Puppet::Parser::ResourceType.new(:hostclass, "foo", arg.to_sym => "something")
                type.send(arg).should == "something"
            end
        end

        it "should set any provided arguments with the keys as symbols" do
            type = Puppet::Parser::ResourceType.new(:hostclass, "foo", :arguments => {:foo => "bar", :baz => "biz"})
            type.should be_validattr("foo")
            type.should be_validattr("baz")
        end

        it "should set any provided arguments with they keys as strings" do
            type = Puppet::Parser::ResourceType.new(:hostclass, "foo", :arguments => {"foo" => "bar", "baz" => "biz"})
            type.should be_validattr(:foo)
            type.should be_validattr(:baz)
        end

        it "should function if provided no arguments" do
            type = Puppet::Parser::ResourceType.new(:hostclass, "foo")
            type.should_not be_validattr(:foo)
        end
    end

    describe "when testing the validity of an attribute" do
        it "should return true if the parameter was typed at initialization" do
            Puppet::Parser::ResourceType.new(:hostclass, "foo", :arguments => {"foo" => "bar"}).should be_validattr("foo")
        end

        it "should return true if it is a metaparam" do
            Puppet::Parser::ResourceType.new(:hostclass, "foo").should be_validattr("require")
        end

        it "should return true if the parameter is named 'name'" do
            Puppet::Parser::ResourceType.new(:hostclass, "foo").should be_validattr("name")
        end

        it "should return false if it is not a metaparam and was not provided at initialization" do
            Puppet::Parser::ResourceType.new(:hostclass, "foo").should_not be_validattr("yayness")
        end
    end

    describe "when creating a subscope" do
        before do
            @scope = stub 'scope', :newscope => nil
            @resource = stub 'resource'
            @type = Puppet::Parser::ResourceType.new(:hostclass, "foo")
        end

        it "should return a new scope created with the provided scope as the parent" do
            @scope.expects(:newscope).returns "foo"
            @type.subscope(@scope, @resource).should == "foo"
        end

        it "should set the source as itself" do
            @scope.expects(:newscope).with { |args| args[:source] == @type }
            @type.subscope(@scope, @resource)
        end

        it "should set the scope's namespace to its namespace" do
            @type.expects(:namespace).returns "yayness"
            @scope.expects(:newscope).with { |args| args[:namespace] == "yayness" }
            @type.subscope(@scope, @resource)
        end

        it "should set the scope's resource to the provided resource" do
            @scope.expects(:newscope).with { |args| args[:resource] == @resource }
            @type.subscope(@scope, @resource)
        end
    end

    describe "when setting its parameters in the scope" do
        before do
            @scope = stub 'scope', :newscope => nil, :setvar => nil
            @resource = stub 'resource', :title => "yay", :name => "yea", :ref => "Foo[bar]"
            @type = Puppet::Parser::ResourceType.new(:hostclass, "foo")
        end

        it "should set each of the resource's parameters as variables in the scope" do
            @type.set_arguments :foo => nil, :boo => nil
            @resource.expects(:to_hash).returns(:foo => "bar", :boo => "baz")

            @scope.expects(:setvar).with("foo", "bar")
            @scope.expects(:setvar).with("boo", "baz")
            @scope.stubs(:class_set).with("foo",@scope)

            @type.set_resource_parameters(@resource, @scope)
        end

        it "should set the variables as strings" do
            @type.set_arguments :foo => nil
            @resource.expects(:to_hash).returns(:foo => "bar")
            @scope.expects(:setvar).with("foo", "bar")
            @scope.stubs(:class_set).with("foo",@scope)

            @type.set_resource_parameters(@resource, @scope)
        end

        it "should fail if any of the resource's parameters are not valid attributes" do
            @type.set_arguments :foo => nil
            @resource.expects(:to_hash).returns(:boo => "baz")

            lambda { @type.set_resource_parameters(@resource, @scope) }.should raise_error(Puppet::ParseError)
        end

        it "should evaluate and set its default values as variables for parameters not provided by the resource" do
            @type.set_arguments :foo => stub("value", :safeevaluate => "something")
            @resource.expects(:to_hash).returns({})

            @scope.expects(:setvar).with("foo", "something")
            @scope.stubs(:class_set).with("foo",@scope)

            @type.set_resource_parameters(@resource, @scope)
        end

        it "should fail if the resource does not provide a value for a required argument" do
            @type.set_arguments :foo => nil
            @resource.expects(:to_hash).returns({})

            lambda { @type.set_resource_parameters(@resource, @scope) }.should raise_error(Puppet::ParseError)
        end

        it "should set the resource's title as a variable if not otherwise provided" do
            @resource.expects(:to_hash).returns({})

            @resource.expects(:title).returns 'teetle'
            @scope.expects(:setvar).with("title", "teetle")
            @scope.stubs(:class_set).with("foo",@scope)

            @type.set_resource_parameters(@resource, @scope)
        end

        it "should set the resource's name as a variable if not otherwise provided" do
            @resource.expects(:to_hash).returns({})

            @resource.expects(:name).returns 'nombre'
            @scope.expects(:setvar).with("name", "nombre")
            @scope.stubs(:class_set).with("foo",@scope)

            @type.set_resource_parameters(@resource, @scope)
        end
    end

    describe "when describing and managing parent classes" do
        before do
            @code = Puppet::Parser::LoadedCode.new
            @parent = Puppet::Parser::ResourceType.new(:hostclass, "bar")
            @code.add @parent

            @child = Puppet::Parser::ResourceType.new(:hostclass, "foo", :parent => "bar")
            @code.add @child
        end

        it "should be able to define a parent" do
            Puppet::Parser::ResourceType.new(:hostclass, "foo", :parent => "bar")
        end

        it "should use the code collection to find the parent resource type" do
            @child.parent_type.should equal(@parent)
        end

        it "should be able to find parent nodes" do
            parent = Puppet::Parser::ResourceType.new(:node, "bar")
            @code.add parent
            child = Puppet::Parser::ResourceType.new(:node, "foo", :parent => "bar")
            @code.add child

            child.parent_type.should equal(parent)
        end

        it "should cache a reference to the parent type" do
            @code.expects(:hostclass).once.with("bar").returns @parent
            @child.parent_type
            @child.parent_type
        end

        it "should correctly state when it is another type's child" do
            @child.should be_child_of(@parent)
        end

        it "should be considered the child of a parent's parent" do
            @grandchild = Puppet::Parser::ResourceType.new(:hostclass, "baz", :parent => "foo")
            @code.add @grandchild

            @grandchild.should be_child_of(@parent)
        end

        it "should correctly state when it is not another type's child" do
            @notchild = Puppet::Parser::ResourceType.new(:hostclass, "baz")
            @code.add @notchild

            @notchild.should_not be_child_of(@parent)
        end
    end

    describe "when evaluating its code" do
        before do
            @scope = stub 'scope', :newscope => nil, :setvar => nil
            @resource = stub 'resource', :title => "yay", :name => "yea", :ref => "Foo[bar]", :scope => @scope
            @type = Puppet::Parser::ResourceType.new(:hostclass, "foo")
            @type.stubs(:set_resource_parameters)
        end

        it "should set all of its parameters in a subscope" do
            subscope = stub 'subscope'
            @type.expects(:subscope).with(@scope, @resource).returns subscope
            @type.expects(:set_resource_parameters).with(@resource, subscope)

            @type.evaluate_code(@resource)
        end

        it "should evaluate the code if any is provided" do
            code = stub 'code'
            @type.expects(:code).returns code
            @type.stubs(:subscope).returns stub("subscope")
            code.expects(:safeevaluate).with @type.subscope

            @type.evaluate_code(@resource)
        end

        it "should noop if there is no code" do
            @type.expects(:code).returns nil
            @type.stubs(:subscope).returns stub("subscope")

            @type.evaluate_code(@resource)
        end
    end

    describe "when creating a resource" do
        before do
            @catalog = Puppet::Resource::Catalog.new
            @node = stub 'node', :name => "foo", :classes => []
            @compiler = Puppet::Parser::Compiler.new(@node, @catalog)
            @scope = Puppet::Parser::Scope.new
            @scope.stubs(:compiler).returns @compiler

            @top = Puppet::Parser::ResourceType.new :hostclass, "top"
            @middle = Puppet::Parser::ResourceType.new :hostclass, "middle", :parent => "top"

            @code = Puppet::Parser::LoadedCode.new
            @code.add @top
            @code.add @middle
        end

        it "should create a resource instance" do
            @top.mk_plain_resource(@scope).should be_instance_of(Puppet::Parser::Resource)
        end

        it "should set its resource type to 'class' when it is a hostclass" do
            Puppet::Parser::ResourceType.new(:hostclass, "top").mk_plain_resource(@scope).type.should == "Class"
        end

        it "should set its resource type to 'node' when it is a node" do
            Puppet::Parser::ResourceType.new(:node, "top").mk_plain_resource(@scope).type.should == "Node"
        end

        it "should fail when it is a definition" do
            lambda { Puppet::Parser::ResourceType.new(:definition, "top").mk_plain_resource(@scope) }.should raise_error(ArgumentError)
        end

        it "should add the created resource to the scope's catalog" do
            @top.mk_plain_resource(@scope)

            @compiler.catalog.resource(:class, "top").should be_instance_of(Puppet::Parser::Resource)
        end

        it "should evaluate the parent class if one exists" do
            @middle.mk_plain_resource(@scope)

            @compiler.catalog.resource(:class, "top").should be_instance_of(Puppet::Parser::Resource)
        end

        it "should fail to evaluate if a parent class is defined but cannot be found" do
            othertop = Puppet::Parser::ResourceType.new :hostclass, "something", :parent => "yay"
            @code.add othertop
            lambda { othertop.mk_plain_resource(@scope) }.should raise_error(Puppet::ParseError)
        end

        it "should not create a new resource if one already exists" do
            @compiler.catalog.expects(:resource).with(:class, "top").returns("something")
            @compiler.catalog.expects(:add_resource).never
            @top.mk_plain_resource(@scope)
        end

        it "should return the existing resource when not creating a new one" do
            @compiler.catalog.expects(:resource).with(:class, "top").returns("something")
            @compiler.catalog.expects(:add_resource).never
            @top.mk_plain_resource(@scope).should == "something"
        end

        it "should not create a new parent resource if one already exists and it has a parent class" do
            @top.mk_plain_resource(@scope)

            top_resource = @compiler.catalog.resource(:class, "top")

            @middle.mk_plain_resource(@scope)

            @compiler.catalog.resource(:class, "top").should equal(top_resource)
        end

        # #795 - tag before evaluation.
        it "should tag the catalog with the resource tags when it is evaluated" do
            @middle.mk_plain_resource(@scope)

            @compiler.catalog.should be_tagged("middle")
        end

        it "should tag the catalog with the parent class tags when it is evaluated" do
            @middle.mk_plain_resource(@scope)

            @compiler.catalog.should be_tagged("top")
        end
    end

    describe "when merging code from another instance" do
        def code(str)
            Puppet::Parser::AST::Leaf.new :value => str
        end

        it "should fail unless it is a class" do
            lambda { Puppet::Parser::ResourceType.new(:node, "bar").merge("foo") }.should raise_error(ArgumentError)
        end

        it "should fail unless the source instance is a class" do
            dest = Puppet::Parser::ResourceType.new(:hostclass, "bar")
            source = Puppet::Parser::ResourceType.new(:node, "foo")
            lambda { dest.merge(source) }.should raise_error(ArgumentError)
        end

        it "should fail if both classes have different parent classes" do
            code = Puppet::Parser::LoadedCode.new
            {"a" => "b", "c" => "d"}.each do |parent, child|
                code.add Puppet::Parser::ResourceType.new(:hostclass, parent)
                code.add Puppet::Parser::ResourceType.new(:hostclass, child, :parent => parent)
            end
            lambda { code.hostclass("b").merge(code.hostclass("d")) }.should raise_error(ArgumentError)
        end

        it "should copy the other class's parent if it has not parent" do
            dest = Puppet::Parser::ResourceType.new(:hostclass, "bar")

            parent = Puppet::Parser::ResourceType.new(:hostclass, "parent")
            source = Puppet::Parser::ResourceType.new(:hostclass, "foo", :parent => "parent")
            dest.merge(source)

            dest.parent.should == "parent"
        end

        it "should copy the other class's documentation as its docs if it has no docs" do
            dest = Puppet::Parser::ResourceType.new(:hostclass, "bar")
            source = Puppet::Parser::ResourceType.new(:hostclass, "foo", :doc => "yayness")
            dest.merge(source)

            dest.doc.should == "yayness"
        end

        it "should append the other class's docs to its docs if it has any" do
            dest = Puppet::Parser::ResourceType.new(:hostclass, "bar", :doc => "fooness")
            source = Puppet::Parser::ResourceType.new(:hostclass, "foo", :doc => "yayness")
            dest.merge(source)

            dest.doc.should == "foonessyayness"
        end

        it "should turn its code into an ASTArray if necessary" do
            dest = Puppet::Parser::ResourceType.new(:hostclass, "bar", :code => code("foo"))
            source = Puppet::Parser::ResourceType.new(:hostclass, "foo", :code => code("bar"))

            dest.merge(source)

            dest.code.should be_instance_of(Puppet::Parser::AST::ASTArray)
        end

        it "should set the other class's code as its code if it has none" do
            dest = Puppet::Parser::ResourceType.new(:hostclass, "bar")
            source = Puppet::Parser::ResourceType.new(:hostclass, "foo", :code => code("bar"))

            dest.merge(source)

            dest.code.value.should == "bar"
        end

        it "should append the other class's code to its code if it has any" do
            dcode = Puppet::Parser::AST::ASTArray.new :children => [code("dest")]
            dest = Puppet::Parser::ResourceType.new(:hostclass, "bar", :code => dcode)

            scode = Puppet::Parser::AST::ASTArray.new :children => [code("source")]
            source = Puppet::Parser::ResourceType.new(:hostclass, "foo", :code => scode)

            dest.merge(source)

            dest.code.children.collect { |l| l.value }.should == %w{dest source}
        end
    end
end
