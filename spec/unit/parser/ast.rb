#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

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
