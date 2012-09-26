#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::AST::IfStatement do
  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
  end

  describe "when evaluating" do

    before :each do
      @test = stub 'test'
      @test.stubs(:safeevaluate).with(@scope)

      @stmt = stub 'stmt'
      @stmt.stubs(:safeevaluate).with(@scope)

      @else = stub 'else'
      @else.stubs(:safeevaluate).with(@scope)

      @ifstmt = Puppet::Parser::AST::IfStatement.new :test => @test, :statements => @stmt
      @ifelsestmt = Puppet::Parser::AST::IfStatement.new :test => @test, :statements => @stmt, :else => @else
    end

    it "should evaluate test" do
      Puppet::Parser::Scope.stubs(:true?).returns(false)

      @test.expects(:safeevaluate).with(@scope)

      @ifstmt.evaluate(@scope)
    end

    it "should evaluate if statements if test is true" do
      Puppet::Parser::Scope.stubs(:true?).returns(true)

      @stmt.expects(:safeevaluate).with(@scope)

      @ifstmt.evaluate(@scope)
    end

    it "should not evaluate if statements if test is false" do
      Puppet::Parser::Scope.stubs(:true?).returns(false)

      @stmt.expects(:safeevaluate).with(@scope).never

      @ifstmt.evaluate(@scope)
    end

    it "should evaluate the else branch if test is false" do
      Puppet::Parser::Scope.stubs(:true?).returns(false)

      @else.expects(:safeevaluate).with(@scope)

      @ifelsestmt.evaluate(@scope)
    end

    it "should not evaluate the else branch if test is true" do
      Puppet::Parser::Scope.stubs(:true?).returns(true)

      @else.expects(:safeevaluate).with(@scope).never

      @ifelsestmt.evaluate(@scope)
    end

    it "should reset ephemeral statements after evaluation" do
      @scope.expects(:ephemeral_level).returns(:level)
      Puppet::Parser::Scope.stubs(:true?).returns(true)

      @stmt.expects(:safeevaluate).with(@scope)
      @scope.expects(:unset_ephemeral_var).with(:level)

      @ifstmt.evaluate(@scope)
    end
  end
end
