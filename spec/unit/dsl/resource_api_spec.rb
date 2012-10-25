#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/dsl/resource_api'

describe Puppet::DSL::ResourceAPI do
  before do
    @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("foo"))
    @scope = Puppet::Parser::Scope.new(@compiler, :source => "foo")
    @resource = Puppet::Parser::Resource.new(:mytype, "myresource", :scope => @scope)
    @api = Puppet::DSL::ResourceAPI.new(@resource, @scope, proc { })
  end

  it "should include the resource type collection helper" do
    Puppet::DSL::ResourceAPI.ancestors.should be_include(Puppet::Resource::TypeCollectionHelper)
  end

  it "should use the scope's environment as its environment" do
    @scope.expects(:environment).returns "myenv"
    @api.environment.should == "myenv"
  end

  it "should be able to set all of its parameters as instance variables" do
    @resource["foo"] = "myval"
    @api.set_instance_variables
    @api.instance_variable_get("@foo").should == "myval"
  end

  describe "when calling a function" do
    it "should return false if the function does not exist" do
      Puppet::Parser::Functions.expects(:function).with("myfunc").returns nil
      @api.call_function("myfunc", "foo").should be_false
    end

    it "should use the scope the call the provided function with the provided arguments and return the results" do
      scope = stub 'scope'
      @api.stubs(:scope).returns scope
      Puppet::Parser::Functions.expects(:function).with("myfunc").returns "myfunc_method"

      scope.expects(:myfunc_method).with("one", "two")
      @api.call_function("myfunc", ["one", "two"])
    end

    it "should call 'include' when asked to call 'acquire'" do
      scope = stub 'scope'
      @api.stubs(:scope).returns scope
      @api.stubs(:valid_type?).returns false

      scope.expects(:function_include).with("one", "two")
      @api.acquire("one", "two")
    end
  end

  describe "when determining if a provided name is a valid type" do
    it "should be valid if it's :class" do
      @api.should be_valid_type(:class)
    end

    it "should be valid if it's :node" do
      @api.should be_valid_type(:node)
    end

    it "should be valid if it's a builtin type" do
      Puppet::Type.expects(:type).with(:mytype).returns "whatever"
      @api.should be_valid_type(:mytype)
    end

    it "should be valid if it's a defined resource type in the environment's known resource types" do
      collection = stub 'collection'
      @api.stubs(:known_resource_types).returns collection
      collection.expects(:definition).with(:mytype).returns "whatever"
      @api.should be_valid_type(:mytype)
    end

    it "should not be valid unless it's a node, class, builtin type, or defined resource" do
      collection = stub 'collection'
      @api.stubs(:known_resource_types).returns collection
      collection.expects(:definition).returns nil
      Puppet::Type.expects(:type).returns nil
      @api.should_not be_valid_type(:mytype)
    end
  end

  describe "when creating a resource" do
    before do
      @api.scope.stubs(:source).returns stub("source")
      @api.scope.compiler.stubs(:add_resource)
      @created_resource = Puppet::Parser::Resource.new("yay", "eh", :scope => @api.scope)
    end

    it "should create and return a resource of the type specified" do
      Puppet::Parser::Resource.expects(:new).with { |type, title, args| type == "mytype" }.returns @created_resource
      @api.create_resource("mytype", "myname", {:foo => "bar"}).should == [@created_resource]
    end

    it "should use the name from the first element of the provided argument array" do
      Puppet::Parser::Resource.expects(:new).with { |type, title, args| title == "myname" }.returns @created_resource
      @api.create_resource("mytype", "myname", {:foo => "bar"})
    end

    it "should create multiple resources if the first element of the argument array is an array" do
      second_resource = Puppet::Parser::Resource.new('yay', "eh", :scope => @api.scope)
      Puppet::Parser::Resource.expects(:new).with { |type, title, args| title == "first" }.returns @created_resource
      Puppet::Parser::Resource.expects(:new).with { |type, title, args| title == "second" }.returns @created_resource
      @api.create_resource("mytype", ["first", "second"], {:foo => "bar"})
    end

    it "should provide its scope as the scope" do
      Puppet::Parser::Resource.expects(:new).with { |type, title, args| args[:scope] == @api.scope }.returns @created_resource
      @api.create_resource("mytype", "myname", {:foo => "bar"})
    end

    it "should set each provided argument as a parameter on the created resource" do
      result = @api.create_resource("mytype", "myname", {"foo" => "bar", "biz" => "baz"}).shift
      result["foo"].should == "bar"
      result["biz"].should == "baz"
    end

    it "should add the resource to the scope's copmiler" do
      Puppet::Parser::Resource.expects(:new).returns @created_resource
      @api.scope.compiler.expects(:add_resource).with(@api.scope, @created_resource)
      @api.create_resource("mytype", "myname", {:foo => "bar"})
    end

    it "should fail if the resource parameters are not a hash" do
      lambda { @api.create_resource("mytype", "myname", %w{foo bar}) }.should raise_error(ArgumentError)
    end
  end

  describe "when an unknown method is called" do
    it "should create a resource if the method name is a valid type" do
      @api.expects(:valid_type?).with(:mytype).returns true
      @api.expects(:create_resource).with(:mytype, "myname", {:foo => "bar"}).returns true

      @api.mytype("myname", :foo => "bar")
    end

    it "should call any function whose name matches the undefined method if the name is not a valid type" do
      @api.expects(:valid_type?).with(:myfunc).returns false
      @api.expects(:create_resource).never

      Puppet::Parser::Functions.expects(:function).with(:myfunc).returns true

      @api.expects(:call_function).with(:myfunc, %w{foo bar})

      @api.myfunc("foo", "bar")
    end

    it "should raise a method missing error if the method is neither a type nor a function" do
      @api.expects(:valid_type?).with(:myfunc).returns false
      @api.expects(:create_resource).never

      Puppet::Parser::Functions.expects(:function).with(:myfunc).returns false

      @api.expects(:call_function).never

      lambda { @api.myfunc("foo", "bar") }.should raise_error(NoMethodError)
    end
  end

  it "should mark the specified resource as exported when creating a single exported resource" do
    resources = @api.export @api.file("/my/file", :ensure => :present)
    resources[0].should be_exported
  end

  it "should mark all created resources as exported when creating exported resources using a block" do
    @compiler.expects(:add_resource).with { |s, res| res.exported == true }
    @api.export { file "/my/file", :ensure => :present }
  end

  it "should mark the specified resource as virtual when creating a single virtual resource" do
    resources = @api.virtual @api.file("/my/file", :ensure => :present)
    resources[0].should be_virtual
  end

  it "should mark all created resources as virtual when creating virtual resources using a block" do
    @compiler.expects(:add_resource).with { |s, res| res.virtual == true }
    @api.virtual { file "/my/file", :ensure => :present }
  end
end
