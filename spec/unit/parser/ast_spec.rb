#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/parser/ast'

describe Puppet::Parser::AST do
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
  let(:scope) { stub 'scope' }

  class Evaluateable < Puppet::Parser::AST
    attr_accessor :value
    def safeevaluate(*options)
      return value
    end
  end

  def ast_node_of(value)
    Evaluateable.new(:value => value)
  end

  describe "when evaluate_match is called" do
    it "matches when the values are equal" do
      ast_node_of('value').evaluate_match('value', scope).should be_true
    end

    it "matches in a case insensitive manner" do
      ast_node_of('vALue').evaluate_match('vALuE', scope).should be_true
    end

    it "matches strings that represent numbers" do
      ast_node_of("23").evaluate_match(23, scope).should be_true
    end

    it "matches numbers against strings that represent numbers" do
      ast_node_of(23).evaluate_match("23", scope).should be_true
    end

    it "matches undef if value is an empty string" do
      ast_node_of('').evaluate_match(:undef, scope).should be_true
    end

    it "matches '' if value is undef" do
      ast_node_of(:undef).evaluate_match('', scope).should be_true
    end
  end
end
