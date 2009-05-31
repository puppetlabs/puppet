#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe "the require function" do

    before :each do
        @catalog = stub 'catalog'
        @compiler = stub 'compiler', :catalog => @catalog
        @scope = Puppet::Parser::Scope.new()
        @scope.stubs(:resource).returns("ourselves")
        @scope.stubs(:findresource)
        @scope.stubs(:compiler).returns(@compiler)
    end

    it "should exist" do
        Puppet::Parser::Functions.function("require").should == "function_require"
    end

    it "should delegate to the 'include' puppet function" do
        @catalog.stubs(:add_edge)
        @scope.expects(:function_include).with("myclass")

        @scope.function_require("myclass")
    end

    it "should add a catalog edge from our parent resource to the included one" do
        @scope.stubs(:function_include).with("myclass")
        @scope.stubs(:findresource).with(:class, "myclass").returns("includedclass")

        @catalog.expects(:add_edge).with("ourselves","includedclass")

        @scope.function_require("myclass")
    end

end
