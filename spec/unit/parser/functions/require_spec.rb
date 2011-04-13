#!/usr/bin/env rspec
require 'spec_helper'

describe "the require function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    @catalog = stub 'catalog'
    @compiler = stub 'compiler', :catalog => @catalog, :environment => nil

    @scope = Puppet::Parser::Scope.new
    @scope.stubs(:findresource)
    @scope.stubs(:compiler).returns(@compiler)
    @klass = stub 'class', :name => "myclass"
    @scope.stubs(:find_hostclass).returns(@klass)

    @resource = Puppet::Parser::Resource.new(:file, "/my/file", :scope => @scope, :source => "source")
    @resource.stubs(:metaparam_compatibility_mode?).returns false
    @scope.stubs(:resource).returns @resource
  end

  it "should exist" do
    Puppet::Parser::Functions.function("require").should == "function_require"
  end

  it "should delegate to the 'include' puppet function" do
    @scope.expects(:function_include).with("myclass")

    @scope.function_require("myclass")
  end

  it "should set the 'require' prarameter on the resource to a resource reference" do
    @scope.stubs(:function_include)
    @scope.function_require("myclass")

    @resource["require"].should be_instance_of(Array)
    @resource["require"][0].should be_instance_of(Puppet::Resource)
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
    @klass.expects(:name).returns("myclass")

    @scope.function_require("myclass")
  end

  it "should append the required class to the require parameter" do
    @scope.stubs(:function_include)

    one = Puppet::Resource.new(:file, "/one")
    @resource[:require] = one
    @scope.function_require("myclass")

    @resource[:require].should be_include(one)
    @resource[:require].detect { |r| r.to_s == "Class[Myclass]" }.should be_instance_of(Puppet::Resource)
  end
end
