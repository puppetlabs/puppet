#! /usr/bin/env ruby
require 'spec_helper'

describe "the 'include' function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("foo"))
    @scope = Puppet::Parser::Scope.new(@compiler)
  end

  it "should exist" do
    Puppet::Parser::Functions.function("include").should == "function_include"
  end

  it "should include a single class" do
    inc = "foo"
    @compiler.expects(:evaluate_classes).with {|klasses,parser,lazy| klasses == [inc]}.returns([inc])
    @scope.function_include(["foo"])
  end

  it "should include multiple classes" do
    inc = ["foo","bar"]
    @compiler.expects(:evaluate_classes).with {|klasses,parser,lazy| klasses == inc}.returns(inc)
    @scope.function_include(["foo","bar"])
  end

  it "should include multiple classes passed in an array" do
    inc = ["foo","bar"]
    @compiler.expects(:evaluate_classes).with {|klasses,parser,lazy| klasses == inc}.returns(inc)
    @scope.function_include([["foo","bar"]])
  end

  it "should flatten nested arrays" do
    inc = ["foo","bar","baz"]
    @compiler.expects(:evaluate_classes).with {|klasses,parser,lazy| klasses == inc}.returns(inc)
    @scope.function_include([["foo","bar"],"baz"])
  end

  it "should not lazily evaluate the included class" do
    @compiler.expects(:evaluate_classes).with {|klasses,parser,lazy| lazy == false}.returns("foo")
    @scope.function_include(["foo"])
  end

  it "should raise if the class is not found" do
    @scope.stubs(:source).returns(true)
    expect { @scope.function_include(["nosuchclass"]) }.to raise_error(Puppet::Error)
  end

  context "When the future parser is in use" do
    require 'puppet/pops'
    before(:each) do
      Puppet[:parser] = 'future'
    end

    it 'transforms relative names to absolute' do
      @scope.compiler.expects(:evaluate_classes).with(["::myclass"], @scope, false)
      @scope.function_include(["myclass"])
    end

    it 'accepts a Class[name] type' do
      @scope.compiler.expects(:evaluate_classes).with(["::myclass"], @scope, false)
      @scope.function_include([Puppet::Pops::Types::TypeFactory.host_class('myclass')])
    end

    it 'accepts a Resource[class, name] type' do
      @scope.compiler.expects(:evaluate_classes).with(["::myclass"], @scope, false)
      @scope.function_include([Puppet::Pops::Types::TypeFactory.resource('class', 'myclass')])
    end

    it 'raises and error for unspecific Class' do
      expect {
      @scope.function_include([Puppet::Pops::Types::TypeFactory.host_class()])
      }.to raise_error(ArgumentError, /Cannot use an unspecific Class\[\] Type/)
    end

    it 'raises and error for Resource that is not of class type' do
      expect {
      @scope.function_include([Puppet::Pops::Types::TypeFactory.resource('file')])
      }.to raise_error(ArgumentError, /Cannot use a Resource\[file\] where a Resource\['class', name\] is expected/)
    end

    it 'raises and error for Resource[class] that is unspecific' do
      expect {
      @scope.function_include([Puppet::Pops::Types::TypeFactory.resource('class')])
      }.to raise_error(ArgumentError, /Cannot use an unspecific Resource\['class'\] where a Resource\['class', name\] is expected/)
    end
  end

end
