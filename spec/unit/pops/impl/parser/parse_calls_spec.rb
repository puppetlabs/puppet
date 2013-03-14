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
require File.join(File.dirname(__FILE__), '/parser_rspec_helper')

RSpec.configure do |c|
  c.include ParserRspecHelper
end

# Tests calls  
describe Puppet::Pops::Impl::Parser::Parser do
  Model ||= Puppet::Pops::API::Model
  context "When running these examples, the setup" do

    it "should include a ModelTreeDumper for convenient string comparisons" do
      x = literal(10) + literal(20)
      dump(x).should == "(+ 10 20)"
    end

    it "should parse a code string and return a model" do
      model = parse("$a = 10").current
      model.class.should == Model::AssignmentExpression
      dump(model).should == "(= $a 10)"
    end
   end

  context "When parsing calls as statements" do
    context "in top level scope" do
      it "foo()" do
        dump(parse("foo()")).should == "(invoke foo)"      
      end
      it "foo bar" do
        dump(parse("foo bar")).should == "(invoke foo bar)"      
      end
      it "foo(bar)" do
        dump(parse("foo(bar)")).should == "(invoke foo bar)"      
      end
      it "foo(bar,)" do
        dump(parse("foo(bar,)")).should == "(invoke foo bar)"      
      end
      it "foo(bar, fum,)" do
        dump(parse("foo(bar,fum,)")).should == "(invoke foo bar fum)"      
      end
    end
    context "in nested scopes" do
      it "if true { foo() }" do
        dump(parse("if true {foo()}")).should == "(if true\n  (then (invoke foo)))"      
      end
      it "if true { foo bar}" do
        dump(parse("if true {foo bar}")).should == "(if true\n  (then (invoke foo bar)))"      
      end
    end
  end
  context "When parsing calls as expressions" do
    it "$a = foo()" do
      dump(parse("$a = foo()")).should == "(= $a (call foo))"      
    end
    it "$a = foo(bar)" do
      dump(parse("$a = foo()")).should == "(= $a (call foo))"      
    end
    it "$a = foo bar # illegal, must have parentheses" do
      expect { dump(parse("$a = foo bar"))}.to raise_error(Puppet::ParseError)      
    end
    context "in nested scopes" do
      it "if true { $a = foo() }" do
        dump(parse("if true { $a = foo()}")).should == "(if true\n  (then (= $a (call foo))))"      
      end
      it "if true { $a= foo(bar)}" do
        dump(parse("if true {$a = foo(bar)}")).should == "(if true\n  (then (= $a (call foo bar))))"      
      end
    end
  end
  context "When parsing method calls" do
    it "$a.foo" do
      dump(parse("$a.foo")).should == "(call-method (. $a foo))"
    end
    it "$a.foo {|| }" do
#      dump(parse("$a.foo {|| }")).should == "(call-method (. $a foo) (lambda ()))"
      dump(parse("$a.foo || { }")).should == "(call-method (. $a foo) (lambda ()))"
    end
    it "$a.foo {|$x| }" do
      dump(parse("$a.foo {|$x| }")).should == "(call-method (. $a foo) (lambda (parameters x) ()))"
    end
    it "$a.foo {|$x| }" do
      dump(parse("$a.foo {|$x| $b = $x}")).should == 
        "(call-method (. $a foo) (lambda (parameters x) (block (= $b $x))))"
    end
  end
end