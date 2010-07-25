#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe "the 'include' function" do

  before :each do
    Puppet::Node::Environment.stubs(:current).returns(nil)
    @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("foo"))
    @scope = Puppet::Parser::Scope.new(:compiler => @compiler)
    # MQR TODO: Without the following stub these tests cause hundreds of spurious errors in
    #           subsequent tests.  With it, there are no spurious failures and all but one
    #           of the tests (marked pending, bellow) fail.  This needs a better solution.
    Puppet::Parser::Resource.stubs(:new).with('stage', :main, :scope => @scope).returns 'foo'
  end

  it "should exist" do
    Puppet::Parser::Functions.function("include").should == "function_include"
  end

  it "should include a single class" do
    inc = "foo"
    @compiler.expects(:evaluate_classes).with {|klasses,parser,lazy| klasses == [inc]}.returns([inc])
    @scope.function_include("foo")
  end

  it "should include multiple classes" do
    inc = ["foo","bar"]
    @compiler.expects(:evaluate_classes).with {|klasses,parser,lazy| klasses == inc}.returns(inc)
    @scope.function_include(["foo","bar"])
  end

  it "should not lazily evaluate the included class" do
    @compiler.expects(:evaluate_classes).with {|klasses,parser,lazy| lazy == false}.returns("foo")
    @scope.function_include("foo")
  end

  it "should allow a parent to include its child" do
    pending "Resolution of MQR TODO item, above"
    @parent_type = Puppet::Resource::Type.new(:hostclass, "parent")
    @parent_resource = Puppet::Parser::Resource.new(:hostclass, "parent", :scope => @scope)
    @subscope = @parent_type.subscope(@scope,@parent_resource)
    @scope.environment.known_resource_types.stubs(:find_hostclass).with{|nses,name| name.downcase == "parent"}.returns(@parent_type)

    @type = Puppet::Resource::Type.new(:hostclass, "foo")
    @type.stubs(:parent_scope).returns(@subscope)
    @type.parent = "parent"
    @resource = Puppet::Parser::Resource.new(:hostclass, "foo", :scope => @subscope)
    @resource.stubs(:resource_type).returns(@type)
    @scope.environment.known_resource_types.stubs(:find_hostclass).with{|nses,name| name.downcase == "foo"}.returns(@parent_type)
    Puppet::Resource.stubs(:new).returns(@resource)
    Puppet::Parser::Resource.stubs(:new).returns(@resource)
    lambda { @subscope.function_include("foo") }.should_not raise_error
  end
end
