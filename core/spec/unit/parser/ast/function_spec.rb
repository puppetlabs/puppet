#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::AST::Function do
  before :each do
    @scope = mock 'scope'
  end

  describe "when initializing" do
    it "should not fail if the function doesn't exist" do
      Puppet::Parser::Functions.stubs(:function).returns(false)

      expect{ Puppet::Parser::AST::Function.new :name => "dontexist" }.to_not raise_error

    end
  end

  it "should return its representation with to_s" do
    args = stub 'args', :is_a? => true, :to_s => "[a, b]"

    Puppet::Parser::AST::Function.new(:name => "func", :arguments => args).to_s.should == "func(a, b)"
  end

  describe "when evaluating" do

    it "should fail if the function doesn't exist" do
      Puppet::Parser::Functions.stubs(:function).returns(false)
      func = Puppet::Parser::AST::Function.new :name => "dontexist"

      expect{ func.evaluate(@scope) }.to raise_error(Puppet::ParseError)
    end

    it "should fail if the function is a statement used as rvalue" do
      Puppet::Parser::Functions.stubs(:function).with("exist").returns(true)
      Puppet::Parser::Functions.stubs(:rvalue?).with("exist").returns(false)

      func = Puppet::Parser::AST::Function.new :name => "exist", :ftype => :rvalue

      expect{ func.evaluate(@scope) }.to raise_error(Puppet::ParseError, "Function 'exist' does not return a value")
    end

    it "should fail if the function is an rvalue used as statement" do
      Puppet::Parser::Functions.stubs(:function).with("exist").returns(true)
      Puppet::Parser::Functions.stubs(:rvalue?).with("exist").returns(true)

      func = Puppet::Parser::AST::Function.new :name => "exist", :ftype => :statement

      expect{ func.evaluate(@scope) }.to raise_error(Puppet::ParseError,"Function 'exist' must be the value of a statement")
    end

    it "should evaluate its arguments" do
      argument = stub 'arg'
      Puppet::Parser::Functions.stubs(:function).with("exist").returns(true)
      func = Puppet::Parser::AST::Function.new :name => "exist", :ftype => :statement, :arguments => argument
      @scope.stubs(:function_exist)

      argument.expects(:safeevaluate).with(@scope).returns(["argument"])

      func.evaluate(@scope)
    end

    it "should call the underlying ruby function" do
      argument = stub 'arg', :safeevaluate => ["nothing"]
      Puppet::Parser::Functions.stubs(:function).with("exist").returns(true)
      func = Puppet::Parser::AST::Function.new :name => "exist", :ftype => :statement, :arguments => argument

      @scope.expects(:function_exist).with(["nothing"])

      func.evaluate(@scope)
    end

    it "should convert :undef to '' in arguments" do
      argument = stub 'arg', :safeevaluate => ["foo", :undef, "bar"]
      Puppet::Parser::Functions.stubs(:function).with("exist").returns(true)
      func = Puppet::Parser::AST::Function.new :name => "exist", :ftype => :statement, :arguments => argument

      @scope.expects(:function_exist).with(["foo", "", "bar"])

      func.evaluate(@scope)
    end

    it "should return the ruby function return for rvalue functions" do
      argument = stub 'arg', :safeevaluate => ["nothing"]
      Puppet::Parser::Functions.stubs(:function).with("exist").returns(true)
      func = Puppet::Parser::AST::Function.new :name => "exist", :ftype => :statement, :arguments => argument
      @scope.stubs(:function_exist).with(["nothing"]).returns("returning")

      func.evaluate(@scope).should == "returning"
    end

  end
end
