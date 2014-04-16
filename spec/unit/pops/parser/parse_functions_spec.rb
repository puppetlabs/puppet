#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/parser_rspec_helper')

describe "egrammar parsing function definitions" do
  include ParserRspecHelper

  context "when defining a function" do
    it "it can be dumped" do
      dump(parse("function foo() { }")).should == "(function foo ())"
    end

    it "typed parameters are dumped" do
      dump(parse("function foo(String $a) { }")).should == "(function foo (parameters (t string a)) ())"
    end

    it "last captures rest is dumped" do
      dump(parse("function foo(String *$a) { }")).should == "(function foo (parameters (t string *a)) ())"
    end

    it "the body is dumped" do
      dump(parse("function foo() { 10 }")).should == "(function foo (block 10))"
    end
  end
end
