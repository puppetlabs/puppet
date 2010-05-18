#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe "the require function" do

    before :each do
        @catalog = stub 'catalog'
        @compiler = stub 'compiler', :catalog => @catalog

        @resource = stub 'resource', :set_parameter => nil, :metaparam_compatibility_mode? => false, :[] => nil
        @scope = Puppet::Parser::Scope.new()
        @scope.stubs(:resource).returns @resource
        @scope.stubs(:findresource)
        @scope.stubs(:compiler).returns(@compiler)
        @klass = stub 'class', :classname => "myclass"
        @scope.stubs(:find_hostclass).returns(@klass)
    end

    it "should exist" do
        Puppet::Parser::Functions.function("require").should == "function_require"
    end

    it "should delegate to the 'include' puppet function" do
        @scope.expects(:function_include).with("myclass")

        @scope.function_require("myclass")
    end

    it "should set the 'require' prarameter on the resource to a resource reference" do
        @resource.expects(:set_parameter).with { |name, value| name == :require and value[0].is_a?(Puppet::Parser::Resource::Reference) }
        @scope.stubs(:function_include)
        @scope.function_require("myclass")
    end

    it "should verify the 'include' function is loaded" do
        Puppet::Parser::Functions.expects(:function).with(:include).returns(:function_include)
        @scope.stubs(:function_include)
        @scope.function_require("myclass")
    end

    it "should include the class but not add a dependency if used on a client not at least version 0.25" do
        @resource.expects(:metaparam_compatibility_mode?).returns true
        @scope.expects(:warning)
        @resource.expects(:set_parameter).never
        @scope.expects(:function_include)

        @scope.function_require("myclass")
    end

    it "should lookup the absolute class path" do
        @scope.stubs(:function_include)

        @scope.expects(:find_hostclass).with("myclass").returns(@klass)
        @klass.expects(:classname).returns("myclass")

        @scope.function_require("myclass")
    end

    it "should append the required class to the require parameter" do
        @scope.stubs(:function_include)
        Puppet::Parser::Resource::Reference.stubs(:new).returns(:require2)

        @resource.expects(:[]).with(:require).returns(:require1)
        @resource.expects(:set_parameter).with(:require, [:require1, :require2])

        @scope.function_require("myclass")
    end
end
