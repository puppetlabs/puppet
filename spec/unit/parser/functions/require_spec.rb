#! /usr/bin/env ruby
require 'spec_helper'
require 'unit/parser/functions/shared'
require 'puppet_spec/compiler'

describe "the require function" do
  include PuppetSpec::Compiler
#  before :all do
#    Puppet::Parser::Functions.autoloader.loadall
#  end

  before :each do
    @catalog = stub 'catalog'

    node      = Puppet::Node.new('localhost')
    compiler  = Puppet::Parser::Compiler.new(node)
    @scope = Puppet::Parser::Scope.new(compiler)

    @scope.stubs(:findresource)
    @klass = stub 'class', :name => "myclass"
    @scope.stubs(:find_hostclass).returns(@klass)

    @resource = Puppet::Parser::Resource.new(:file, "/my/file", :scope => @scope, :source => "source")
    @scope.stubs(:resource).returns @resource
  end

  it "should exist" do
    expect(Puppet::Parser::Functions.function("require")).to eq("function_require")
  end

  it "should delegate to the 'include' puppet function" do
    @scope.compiler.expects(:evaluate_classes).with(["::myclass"], @scope, false)

    @scope.function_require(["myclass"])
  end

  it "should set the 'require' parameter on the resource to a resource reference" do
    @scope.compiler.stubs(:evaluate_classes)
    @scope.function_require(["myclass"])

    expect(@resource["require"]).to be_instance_of(Array)
    expect(@resource["require"][0]).to be_instance_of(Puppet::Resource)
  end

  it "should lookup the absolute class path" do
    @scope.compiler.stubs(:evaluate_classes)

    @scope.expects(:find_hostclass).with("::myclass").returns(@klass)
    @klass.expects(:name).returns("myclass")

    @scope.function_require(["myclass"])
  end

  it "should append the required class to the require parameter" do
    @scope.compiler.stubs(:evaluate_classes)

    one = Puppet::Resource.new(:file, "/one")
    @resource[:require] = one
    @scope.function_require(["myclass"])

    expect(@resource[:require]).to be_include(one)
    expect(@resource[:require].detect { |r| r.to_s == "Class[Myclass]" }).to be_instance_of(Puppet::Resource)
  end

  it_should_behave_like 'all functions transforming relative to absolute names', :function_require
  it_should_behave_like 'an inclusion function, regardless of the type of class reference,', :require

end
