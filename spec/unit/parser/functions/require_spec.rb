#! /usr/bin/env ruby
require 'spec_helper'

describe "the require function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

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
    Puppet::Parser::Functions.function("require").should == "function_require"
  end

  it "should delegate to the 'include' puppet function" do
    @scope.compiler.expects(:evaluate_classes).with(["myclass"], @scope, false)

    @scope.function_require(["myclass"])
  end

  it "should set the 'require' parameter on the resource to a resource reference" do
    @scope.compiler.stubs(:evaluate_classes)
    @scope.function_require(["myclass"])

    @resource["require"].should be_instance_of(Array)
    @resource["require"][0].should be_instance_of(Puppet::Resource)
  end

  it "should lookup the absolute class path" do
    @scope.compiler.stubs(:evaluate_classes)

    @scope.expects(:find_hostclass).with("myclass").returns(@klass)
    @klass.expects(:name).returns("myclass")

    @scope.function_require(["myclass"])
  end

  it "should append the required class to the require parameter" do
    @scope.compiler.stubs(:evaluate_classes)

    one = Puppet::Resource.new(:file, "/one")
    @resource[:require] = one
    @scope.function_require(["myclass"])

    @resource[:require].should be_include(one)
    @resource[:require].detect { |r| r.to_s == "Class[Myclass]" }.should be_instance_of(Puppet::Resource)
  end

  context "When the future parser is in use" do
    require 'puppet/pops'
    before(:each) do
      Puppet[:parser] = 'future'
    end

    it 'transforms relative names to absolute' do
      @scope.compiler.expects(:evaluate_classes).with(["::myclass"], @scope, false)
      @scope.function_require(["myclass"])
    end

    it 'accepts a Class[name] type' do
      @scope.compiler.expects(:evaluate_classes).with(["::myclass"], @scope, false)
      @scope.function_require([Puppet::Pops::Types::TypeFactory.host_class('myclass')])
    end

    it 'accepts a Resource[class, name] type' do
      @scope.compiler.expects(:evaluate_classes).with(["::myclass"], @scope, false)
      @scope.function_require([Puppet::Pops::Types::TypeFactory.resource('class', 'myclass')])
    end

    it 'raises and error for unspecific Class' do
      expect {
      @scope.function_require([Puppet::Pops::Types::TypeFactory.host_class()])
      }.to raise_error(ArgumentError, /Cannot use an unspecific Class\[\] Type/)
    end

    it 'raises and error for Resource that is not of class type' do
      expect {
      @scope.function_require([Puppet::Pops::Types::TypeFactory.resource('file')])
      }.to raise_error(ArgumentError, /Cannot use a Resource\[file\] where a Resource\['class', name\] is expected/)
    end

    it 'raises and error for Resource[class] that is unspecific' do
      expect {
      @scope.function_require([Puppet::Pops::Types::TypeFactory.resource('class')])
      }.to raise_error(ArgumentError, /Cannot use an unspecific Resource\['class'\] where a Resource\['class', name\] is expected/)
    end
  end
end
