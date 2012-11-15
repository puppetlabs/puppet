#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::AST::CaseStatement do
  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
  end

  describe "when evaluating" do

    before :each do
      @test = stub 'test'
      @test.stubs(:safeevaluate).with(@scope).returns("value")

      @option1 = Puppet::Parser::AST::CaseOpt.new({})
      @option1.stubs(:eachopt)
      @option1.stubs(:default?).returns false
      @option2 = Puppet::Parser::AST::CaseOpt.new({})
      @option2.stubs(:eachopt)
      @option2.stubs(:default?).returns false

      @options = Puppet::Parser::AST::ASTArray.new(:children => [@option1, @option2])

      @casestmt = Puppet::Parser::AST::CaseStatement.new :test => @test, :options => @options
    end

    it "should evaluate test" do
      @test.expects(:safeevaluate).with(@scope)

      @casestmt.evaluate(@scope)
    end

    it "should scan each option" do
      @casestmt.evaluate(@scope)
    end

    describe "when scanning options" do
      before :each do
        @opval1 = stub_everything 'opval1'
        @option1.stubs(:eachopt).yields(@opval1)

        @opval2 = stub_everything 'opval2'
        @option2.stubs(:eachopt).yields(@opval2)
      end

      it "should evaluate each sub-option" do
        @option1.expects(:eachopt)
        @option2.expects(:eachopt)

        @casestmt.evaluate(@scope)
      end

      it "should evaluate first matching option" do
        @opval2.stubs(:evaluate_match).with { |*arg| arg[0] == "value" }.returns(true)
        @option2.expects(:safeevaluate).with(@scope)

        @casestmt.evaluate(@scope)
      end

      it "should return the first matching evaluated option" do
        @opval2.stubs(:evaluate_match).with { |*arg| arg[0] == "value" }.returns(true)
        @option2.stubs(:safeevaluate).with(@scope).returns(:result)

        @casestmt.evaluate(@scope).should == :result
      end

      it "should evaluate the default option if none matched" do
        @option1.stubs(:default?).returns(true)
        @option1.expects(:safeevaluate).with(@scope)

        @casestmt.evaluate(@scope)
      end

      it "should return the default evaluated option if none matched" do
        @option1.stubs(:default?).returns(true)
        @option1.stubs(:safeevaluate).with(@scope).returns(:result)

        @casestmt.evaluate(@scope).should == :result
      end

      it "should return nil if nothing matched" do
        @casestmt.evaluate(@scope).should be_nil
      end

      it "should match and set scope ephemeral variables" do
        @opval1.expects(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }

        @casestmt.evaluate(@scope)
      end

      it "should evaluate this regex option if it matches" do
        @opval1.stubs(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }.returns(true)

        @option1.expects(:safeevaluate).with(@scope)

        @casestmt.evaluate(@scope)
      end

      it "should return this evaluated regex option if it matches" do
        @opval1.stubs(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }.returns(true)
        @option1.stubs(:safeevaluate).with(@scope).returns(:result)

        @casestmt.evaluate(@scope).should == :result
      end

      it "should unset scope ephemeral variables after option evaluation" do
        @scope.stubs(:ephemeral_level).returns(:level)
        @opval1.stubs(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }.returns(true)
        @option1.stubs(:safeevaluate).with(@scope).returns(:result)

        @scope.expects(:unset_ephemeral_var).with(:level)

        @casestmt.evaluate(@scope)
      end

      it "should not leak ephemeral variables even if evaluation fails" do
        @scope.stubs(:ephemeral_level).returns(:level)
        @opval1.stubs(:evaluate_match).with { |*arg| arg[0] == "value" and arg[1] == @scope }.returns(true)
        @option1.stubs(:safeevaluate).with(@scope).raises

        @scope.expects(:unset_ephemeral_var).with(:level)

        lambda { @casestmt.evaluate(@scope) }.should raise_error
      end
    end

  end

  it "should match if any of the provided options evaluate as true" do
    ast = nil
    AST = Puppet::Parser::AST

    tests = {
      "one" => %w{a b c},
      "two" => %w{e f g}
    }
    options = tests.collect do |result, values|
      values = values.collect { |v| AST::Leaf.new :value => v }

      AST::CaseOpt.new(
        :value      => AST::ASTArray.new(:children => values),
        :statements => AST::Leaf.new(:value => result)
      )
    end
    options << AST::CaseOpt.new(
      :value      => AST::Default.new(:value => "default"), 
      :statements => AST::Leaf.new(:value => "default")
    )

    ast = nil
    param = AST::Variable.new(:value => "testparam")
    ast = AST::CaseStatement.new(:test => param, :options => options)

    tests.each do |should, values|
      values.each do |value|
        node     = Puppet::Node.new('localhost')
        compiler = Puppet::Parser::Compiler.new(node)
        scope    = Puppet::Parser::Scope.new(compiler)
        scope['testparam'] = value
        result = ast.evaluate(scope)

        result.should == should
      end
    end
  end
end
