#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops/api'
require 'puppet/pops/api/model/model'
require 'puppet/pops/impl/model/factory'
require 'puppet/pops/impl/model/model_tree_dumper'
require 'puppet/pops/impl/evaluator_impl'
require 'puppet/pops/impl/base_scope'
require 'puppet/pops/impl/parser/eparser'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/transformer_rspec_helper')

# Tests calls
describe Puppet::Pops::Impl::Parser::Parser do
  include TransformerRspecHelper
  context "When running these examples, the setup" do

    it "should include a ModelTreeDumper for convenient string comparisons" do
      x = literal(10) + literal(20)
      astdump(x).should == "(+ 10 20)"
    end

    it "should parse a code string and return a model" do
      model = parse("$a = 10").current
      model.class.should == Puppet::Pops::API::Model::AssignmentExpression
      astdump(model).should == "(= $a 10)"
    end
  end

  context "When parsing calls as statements" do
    context "in top level scope" do
      it "foo()" do
        astdump(parse("foo()")).should == "(invoke foo)"
      end
      it "foo bar" do
        astdump(parse("foo bar")).should == "(invoke foo bar)"
      end
    end
    context "in nested scopes" do
      it "if true { foo() }" do
        astdump(parse("if true {foo()}")).should == "(if true\n  (then (invoke foo)))"
      end
      it "if true { foo bar}" do
        astdump(parse("if true {foo bar}")).should == "(if true\n  (then (invoke foo bar)))"
      end
    end
  end
  context "When parsing calls as expressions" do
    it "$a = foo()" do
      astdump(parse("$a = foo()")).should == "(= $a (call foo))"
    end
    it "$a = foo(bar)" do
      astdump(parse("$a = foo()")).should == "(= $a (call foo))"
    end

    # For egrammar where a bare word can be a "statement"
    it "$a = foo bar # assignment followed by bare word is ok in egrammar" do
      astdump(parse("$a = foo bar")).should == "(block (= $a foo) bar)"
    end

    context "in nested scopes" do
      it "if true { $a = foo() }" do
        astdump(parse("if true { $a = foo()}")).should == "(if true\n  (then (= $a (call foo))))"
      end
      it "if true { $a= foo(bar)}" do
        astdump(parse("if true {$a = foo(bar)}")).should == "(if true\n  (then (= $a (call foo bar))))"
      end
    end
  end
  context "When parsing method calls" do
    it "$a.foo" do
      astdump(parse("$a.foo")).should == "(call-method (. $a foo))"
    end
    it "$a.foo {|| }" do
      astdump(parse("$a.foo || { }")).should == "(call-method (. $a foo) (lambda ()))"
    end
    it "$a.foo {|| []} # check transformation to block with empty array" do
      astdump(parse("$a.foo || { []}")).should == "(call-method (. $a foo) (lambda (block ([]))))"
    end
    it "$a.foo {|$x| }" do
      astdump(parse("$a.foo {|$x| }")).should == "(call-method (. $a foo) (lambda (parameters x) ()))"
    end
    it "$a.foo {|$x| $b = $x}" do
      astdump(parse("$a.foo {|$x| $b = $x}")).should ==
      "(call-method (. $a foo) (lambda (parameters x) (block (= $b $x))))"
    end
  end
end
