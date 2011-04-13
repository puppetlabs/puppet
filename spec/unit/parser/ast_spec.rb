#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/parser/ast'

describe Puppet::Parser::AST do

  it "should use the file lookup module" do
    Puppet::Parser::AST.ancestors.should be_include(Puppet::FileCollection::Lookup)
  end

  it "should have a doc accessor" do
    ast = Puppet::Parser::AST.new({})
    ast.should respond_to(:doc)
  end

  it "should have a use_docs accessor to indicate it wants documentation" do
    ast = Puppet::Parser::AST.new({})
    ast.should respond_to(:use_docs)
  end

  [ Puppet::Parser::AST::Collection, Puppet::Parser::AST::Else,
    Puppet::Parser::AST::Function, Puppet::Parser::AST::IfStatement,
    Puppet::Parser::AST::Resource, Puppet::Parser::AST::ResourceDefaults,
    Puppet::Parser::AST::ResourceOverride, Puppet::Parser::AST::VarDef
  ].each do |k|
    it "#{k}.use_docs should return true" do
      ast = k.new({})
      ast.use_docs.should be_true
    end
  end

  describe "when initializing" do
    it "should store the doc argument if passed" do
      ast = Puppet::Parser::AST.new(:doc => "documentation")
      ast.doc.should == "documentation"
    end
  end

end

describe 'AST Generic Child' do
  before :each do
    @value = stub 'value'
    class Evaluateable < Puppet::Parser::AST
      attr_accessor :value
      def safeevaluate(*options)
        return value
      end
    end
    @evaluateable = Evaluateable.new(:value => @value)
    @scope = stubs 'scope'
  end

  describe "when evaluate_match is called" do
    it "should evaluate itself" do
      @evaluateable.expects(:safeevaluate).with(@scope)

      @evaluateable.evaluate_match("value", @scope)
    end

    it "should match values by equality" do
      @value.expects(:==).with("value").returns(true)

      @evaluateable.evaluate_match("value", @scope)
    end

    it "should downcase the evaluated value if wanted" do
      @value.expects(:downcase).returns("value")

      @evaluateable.evaluate_match("value", @scope)
    end

    it "should convert values to number" do
      Puppet::Parser::Scope.expects(:number?).with(@value).returns(2)
      Puppet::Parser::Scope.expects(:number?).with("23").returns(23)

      @evaluateable.evaluate_match("23", @scope)
    end

    it "should compare 'numberized' values" do
      two = stub_everything 'two'
      one = stub_everything 'one'

      Puppet::Parser::Scope.stubs(:number?).with(@value).returns(one)
      Puppet::Parser::Scope.stubs(:number?).with("2").returns(two)

      one.expects(:==).with(two)

      @evaluateable.evaluate_match("2", @scope)
    end

    it "should match undef if value is an empty string" do
      @evaluateable.value = ''
      @evaluateable.evaluate_match(:undef, @scope).should be_true
    end

    it "should downcase the parameter value if wanted" do
      parameter = stub 'parameter'
      parameter.expects(:downcase).returns("value")

      @evaluateable.evaluate_match(parameter, @scope)
    end

    it "should not match '' if value is undef" do
      @evaluateable.value = :undef
      @evaluateable.evaluate_match('', @scope).should be_false
    end
  end
end
