#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Parser do

    AST = Puppet::Parser::AST

    before :each do
        @parser = Puppet::Parser::Parser.new :environment => "development"
        @true_ast = AST::Boolean.new :value => true
    end

    describe "when parsing append operator" do

        it "should not raise syntax errors" do
            lambda { @parser.parse("$var += something") }.should_not raise_error
        end

        it "shouldraise syntax error on incomplete syntax " do
            lambda { @parser.parse("$var += ") }.should raise_error
        end

        it "should call AST::VarDef with append=true" do
            AST::VarDef.expects(:new).with { |h| h[:append] == true }
            @parser.parse("$var += 2")
        end

        it "should work with arrays too" do
            AST::VarDef.expects(:new).with { |h| h[:append] == true }
            @parser.parse("$var += ['test']")
        end

    end

    describe Puppet::Parser, "when parsing 'if'" do
        it "not, it should create the correct ast objects" do
            AST::Not.expects(:new).with { |h| h[:value].is_a?(AST::Boolean) }
            @parser.parse("if ! true { $var = 1 }")
        
        end

        it "boolean operation, it should create the correct ast objects" do
            AST::BooleanOperator.expects(:new).with { 
                |h| h[:rval].is_a?(AST::Boolean) and h[:lval].is_a?(AST::Boolean) and h[:operator]=="or"
            }
            @parser.parse("if true or true { $var = 1 }")

        end

        it "comparison operation, it should create the correct ast objects" do
             AST::ComparisonOperator.expects(:new).with { 
                 |h| h[:lval].is_a?(AST::Name) and h[:rval].is_a?(AST::Name) and h[:operator]=="<"
             }
             @parser.parse("if 1 < 2 { $var = 1 }")

        end

    end

    describe Puppet::Parser, "when parsing if complex expressions" do
         it "should create a correct ast tree" do
             AST::ComparisonOperator.expects(:new).with { 
                 |h| h[:rval].is_a?(AST::Name) and h[:lval].is_a?(AST::Name) and h[:operator]==">"
             }.returns("whatever")
             AST::ComparisonOperator.expects(:new).with { 
                 |h| h[:rval].is_a?(AST::Name) and h[:lval].is_a?(AST::Name) and h[:operator]=="=="
             }.returns("whatever")
             AST::BooleanOperator.expects(:new).with {
                 |h| h[:rval]=="whatever" and h[:lval]=="whatever" and h[:operator]=="and"                
             }
             @parser.parse("if (1 > 2) and (1 == 2) { $var = 1 }")
         end

         it "should raise an error on incorrect expression" do
             lambda { @parser.parse("if (1 > 2 > ) or (1 == 2) { $var = 1 }") }.should raise_error
        end

     end
 end
