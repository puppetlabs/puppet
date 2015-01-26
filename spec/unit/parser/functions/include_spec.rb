#! /usr/bin/env ruby
require 'spec_helper'
require 'unit/parser/functions/shared'
require 'puppet_spec/compiler'

describe "the 'include' function" do
  include PuppetSpec::Compiler

  before :each do
    @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("foo"))
    @scope = Puppet::Parser::Scope.new(@compiler)
  end

  it "should exist" do
    expect(Puppet::Parser::Functions.function("include")).to eq("function_include")
  end

  it "should include a single class" do
    inc = "::foo"
    @compiler.expects(:evaluate_classes).with {|klasses,parser,lazy| klasses == [inc]}.returns([inc])
    @scope.function_include(["foo"])
  end

  it "should include multiple classes" do
    inc = ["::foo","::bar"]
    @compiler.expects(:evaluate_classes).with {|klasses,parser,lazy| klasses == inc}.returns(inc)
    @scope.function_include(["foo","bar"])
  end

  it "should include multiple classes passed in an array" do
    inc = ["::foo","::bar"]
    @compiler.expects(:evaluate_classes).with {|klasses,parser,lazy| klasses == inc}.returns(inc)
    @scope.function_include([["foo","bar"]])
  end

  it "should flatten nested arrays" do
    inc = ["::foo","::bar","::baz"]
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

  it_should_behave_like 'all functions transforming relative to absolute names', :function_include
  it_should_behave_like 'an inclusion function, regardless of the type of class reference,', :include

end
