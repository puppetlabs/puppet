#! /usr/bin/env ruby
require 'spec_helper'

describe "the split function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
  end

  it "should exist" do
    Puppet::Parser::Functions.function("split").should == "function_split"
  end

  it "should raise an ArgumentError if there is less than 2 arguments" do
    lambda { @scope.function_split(["foo"]) }.should( raise_error(ArgumentError))
  end

  it "should raise an ArgumentError if there is more than 2 arguments" do
    lambda { @scope.function_split(["foo", "bar", "gazonk"]) }.should( raise_error(ArgumentError))
  end

  it "should raise a RegexpError if the regexp is malformed" do
    lambda { @scope.function_split(["foo", "("]) }.should(
        raise_error(RegexpError))
  end


  it "should handle simple string without metacharacters" do
    result = @scope.function_split([ "130;236;254;10", ";"])
    result.should(eql(["130", "236", "254", "10"]))
  end

  it "should handle simple regexps" do
    result = @scope.function_split([ "130.236;254.;10", "[.;]+"])
    result.should(eql(["130", "236", "254", "10"]))
  end

  it "should handle groups" do
    result = @scope.function_split([ "130.236;254.;10", "([.;]+)"])
    result.should(eql(["130", ".", "236", ";", "254", ".;", "10"]))
  end

  it "should handle simple string without metacharacters" do
    result = @scope.function_split([ "130.236.254.10", ";"])
    result.should(eql(["130.236.254.10"]))
  end

end
