#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/transformer_rspec_helper')

describe "transformation to Puppet AST for function calls" do
  include TransformerRspecHelper

  context "When transforming calls as statements" do
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

  context "When transforming calls as expressions" do
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

  context "When transforming method calls" do
    it "$a.foo" do
      astdump(parse("$a.foo")).should == "(call-method (. $a foo))"
    end

    it "$a.foo ||{ }" do
      astdump(parse("$a.foo || { }")).should == "(call-method (. $a foo) (lambda ()))"
    end

    it "$a.foo ||{[]} # check transformation to block with empty array" do
      astdump(parse("$a.foo || {[]}")).should == "(call-method (. $a foo) (lambda (block ([]))))"
    end

    it "$a.foo {|$x| }" do
      astdump(parse("$a.foo |$x| { }")).should == "(call-method (. $a foo) (lambda (parameters x) ()))"
    end

    it "$a.foo |$x| { $b = $x}" do
      astdump(parse("$a.foo |$x| { $b = $x}")).should ==
      "(call-method (. $a foo) (lambda (parameters x) (block (= $b $x))))"
    end
  end
end
