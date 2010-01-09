#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/dsl/resource_api'

describe Puppet::DSL::ResourceAPI do
    before do
        @resource = Puppet::Parser::Resource.new(:type => :mytype, :title => "myresource", :scope => mock("scope"), :source => mock("source"))
        @resource.extend Puppet::DSL::ResourceAPI
    end

    it "should include the resource type collection helper" do
        Puppet::DSL::ResourceAPI.ancestors.should be_include(Puppet::Resource::TypeCollectionHelper)
    end

    it "should be able to set all of its parameters as instance variables" do
        @resource["foo"] = "myval"
        @resource.set_instance_variables
        @resource.instance_variable_get("@foo").should == "myval"
    end

    describe "when calling a function" do
        it "should return false if the function does not exist" do
            Puppet::Parser::Functions.expects(:function).with("myfunc").returns nil
            @resource.call_function("myfunc", "foo").should be_false
        end

        it "should use the scope the call the provided function with the provided arguments and return the results" do
            scope = stub 'scope'
            @resource.stubs(:scope).returns scope
            Puppet::Parser::Functions.expects(:function).with("myfunc").returns "myfunc_method"

            scope.expects(:myfunc_method).with("one", "two")
            @resource.call_function("myfunc", ["one", "two"])
        end
    end

    describe "when determining if a provided name is a valid type" do
        it "should be valid if it's :class" do
            @resource.should be_valid_type(:class)
        end

        it "should be valid if it's :node" do
            @resource.should be_valid_type(:node)
        end

        it "should be valid if it's a builtin type" do
            Puppet::Type.expects(:type).with(:mytype).returns "whatever"
            @resource.should be_valid_type(:mytype)
        end

        it "should be valid if it's a defined resource type in the environment's known resource types" do
            collection = stub 'collection'
            @resource.stubs(:known_resource_types).returns collection
            collection.expects(:definition).with(:mytype).returns "whatever"
            @resource.should be_valid_type(:mytype)
        end

        it "should not be valid unless it's a node, class, builtin type, or defined resource" do
            collection = stub 'collection'
            @resource.stubs(:known_resource_types).returns collection
            collection.expects(:definition).returns nil
            Puppet::Type.expects(:type).returns nil
            @resource.should_not be_valid_type(:mytype)
        end
    end

    describe "when creating a resource" do
        before do
            @resource.scope.stubs(:source).returns stub("source")
            @resource.scope.stubs(:compiler).returns stub("compiler", :add_resource => nil)
            @created_resource = Puppet::Parser::Resource.new(:title => "eh", :type => 'yay', :scope => @resource.scope)
        end

        it "should create and return a resource of the type specified" do
            Puppet::Parser::Resource.expects(:new).with { |args| args[:type] == "mytype" }.returns @created_resource
            @resource.create_resource("mytype", "myname", {:foo => "bar"}).should == [@created_resource]
        end

        it "should use the name from the first element of the provided argument array" do
            Puppet::Parser::Resource.expects(:new).with { |args| args[:title] == "myname" }.returns @created_resource
            @resource.create_resource("mytype", "myname", {:foo => "bar"})
        end

        it "should create multiple resources if the first element of the argument array is an array" do
            second_resource = Puppet::Parser::Resource.new(:title => "eh", :type => 'yay', :scope => @resource.scope)
            Puppet::Parser::Resource.expects(:new).with { |args| args[:title] == "first" }.returns @created_resource
            Puppet::Parser::Resource.expects(:new).with { |args| args[:title] == "second" }.returns @created_resource
            @resource.create_resource("mytype", ["first", "second"], {:foo => "bar"})
        end

        it "should provide its scope as the scope" do
            Puppet::Parser::Resource.expects(:new).with { |args| args[:scope] == @resource.scope }.returns @created_resource
            @resource.create_resource("mytype", "myname", {:foo => "bar"})
        end

        it "should set each provided argument as a parameter on the created resource" do
            result = @resource.create_resource("mytype", "myname", {"foo" => "bar", "biz" => "baz"}).shift
            result["foo"].should == "bar"
            result["biz"].should == "baz"
        end

        it "should add the resource to the scope's copmiler" do
            Puppet::Parser::Resource.expects(:new).returns @created_resource
            @resource.scope.compiler.expects(:add_resource).with(@resource.scope, @created_resource)
            @resource.create_resource("mytype", "myname", {:foo => "bar"})
        end

        it "should fail if the resource parameters are not a hash" do
            lambda { @resource.create_resource("mytype", "myname", %w{foo bar}) }.should raise_error(ArgumentError)
        end
    end

    describe "when an unknown method is called" do
        it "should create a resource if the method name is a valid type" do
            @resource.expects(:valid_type?).with(:mytype).returns true
            @resource.expects(:create_resource).with(:mytype, "myname", {:foo => "bar"}).returns true

            @resource.mytype("myname", :foo => "bar")
        end

        it "should call any function whose name matches the undefined method if the name is not a valid type" do
            @resource.expects(:valid_type?).with(:myfunc).returns false
            @resource.expects(:create_resource).never

            Puppet::Parser::Functions.expects(:function).with(:myfunc).returns true

            @resource.expects(:call_function).with(:myfunc, %w{foo bar})

            @resource.myfunc("foo", "bar")
        end

        it "should raise a method missing error if the method is neither a type nor a function" do
            @resource.expects(:valid_type?).with(:myfunc).returns false
            @resource.expects(:create_resource).never

            Puppet::Parser::Functions.expects(:function).with(:myfunc).returns false

            @resource.expects(:call_function).never

            lambda { @resource.myfunc("foo", "bar") }.should raise_error(NoMethodError)
        end
    end
end
