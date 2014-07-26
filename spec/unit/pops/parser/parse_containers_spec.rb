#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/parser_rspec_helper')

describe "egrammar parsing containers" do
  include ParserRspecHelper

  context "When parsing file scope" do
    it "$a = 10 $b = 20" do
      dump(parse("$a = 10 $b = 20")).should == [
        "(block",
        "  (= $a 10)",
        "  (= $b 20)",
        ")"
        ].join("\n")
    end

    it "$a = 10" do
      dump(parse("$a = 10")).should == "(= $a 10)"
    end
  end

  context "When parsing class" do
    it "class foo {}" do
      dump(parse("class foo {}")).should == "(class foo ())"
    end

    it "class foo { class bar {} }" do
      dump(parse("class foo { class bar {}}")).should == [
        "(class foo (block",
        "  (class foo::bar ())",
        "))"
        ].join("\n")
    end

    it "class foo::bar {}" do
      dump(parse("class foo::bar {}")).should == "(class foo::bar ())"
    end

    it "class foo inherits bar {}" do
      dump(parse("class foo inherits bar {}")).should == "(class foo (inherits bar) ())"
    end

    it "class foo($a) {}" do
      dump(parse("class foo($a) {}")).should == "(class foo (parameters a) ())"
    end

    it "class foo($a, $b) {}" do
      dump(parse("class foo($a, $b) {}")).should == "(class foo (parameters a b) ())"
    end

    it "class foo($a, $b=10) {}" do
      dump(parse("class foo($a, $b=10) {}")).should == "(class foo (parameters a (= b 10)) ())"
    end

    it "class foo($a, $b) inherits belgo::bar {}" do
      dump(parse("class foo($a, $b) inherits belgo::bar{}")).should == "(class foo (inherits belgo::bar) (parameters a b) ())"
    end

    it "class foo {$a = 10 $b = 20}" do
      dump(parse("class foo {$a = 10 $b = 20}")).should == [
        "(class foo (block",
        "  (= $a 10)",
        "  (= $b 20)",
        "))"
        ].join("\n")
    end

    context "it should handle '3x weirdness'" do
      it "class class {} # a class named 'class'" do
        # Not as much weird as confusing that it is possible to name a class 'class'. Can have
        # a very confusing effect when resolving relative names, getting the global hardwired "Class"
        # instead of some foo::class etc.
        # This is allowed in 3.x.
        expect {
          dump(parse("class class {}")).should == "(class class ())"
        }.to raise_error(/not a valid classname/)
      end

      it "class default {} # a class named 'default'" do
        # The weirdness here is that a class can inherit 'default' but not declare a class called default.
        # (It will work with relative names i.e. foo::default though). The whole idea with keywords as
        # names is flawed to begin with - it generally just a very bad idea.
        expect { dump(parse("class default {}")).should == "(class default ())" }.to raise_error(Puppet::ParseError)
      end

      it "class foo::default {} # a nested name 'default'" do
        dump(parse("class foo::default {}")).should == "(class foo::default ())"
      end

      it "class class inherits default {} # inherits default", :broken => true do
        expect {
          dump(parse("class class inherits default {}")).should == "(class class (inherits default) ())"
        }.to raise_error(/not a valid classname/)
      end

      it "class class inherits default {} # inherits default" do
        # TODO: See previous test marked as :broken=>true, it is actually this test (result) that is wacky,
        # this because a class is named at parse time (since class evaluation is lazy, the model must have the
        # full class name for nested classes - only, it gets this wrong when a class is named "class" - or at least
        # I think it is wrong.)
        # 
        expect {
        dump(parse("class class inherits default {}")).should == "(class class::class (inherits default) ())"
          }.to raise_error(/not a valid classname/)
      end

      it "class foo inherits class" do
        expect {
          dump(parse("class foo inherits class {}")).should == "(class foo (inherits class) ())"
        }.to raise_error(/not a valid classname/)
      end
    end

    context 'it should allow keywords as attribute names' do
      ['and', 'case', 'class', 'default', 'define', 'else', 'elsif', 'if', 'in', 'inherits', 'node', 'or',
        'undef', 'unless', 'type', 'attr', 'function', 'private'].each do |keyword|
        it "such as #{keyword}" do
          expect {parse("class x ($#{keyword}){} class { x: #{keyword} => 1 }")}.to_not raise_error
        end
      end
    end

  end

  context "When the parser parses define" do
    it "define foo {}" do
      dump(parse("define foo {}")).should == "(define foo ())"
    end

    it "class foo { define bar {}}" do
      dump(parse("class foo {define bar {}}")).should == [
        "(class foo (block",
        "  (define foo::bar ())",
        "))"
        ].join("\n")
    end

    it "define foo { define bar {}}" do
      # This is illegal, but handled as part of validation
      dump(parse("define foo { define bar {}}")).should == [
        "(define foo (block",
        "  (define bar ())",
        "))"
        ].join("\n")
    end

    it "define foo::bar {}" do
      dump(parse("define foo::bar {}")).should == "(define foo::bar ())"
    end

    it "define foo($a) {}" do
      dump(parse("define foo($a) {}")).should == "(define foo (parameters a) ())"
    end

    it "define foo($a, $b) {}" do
      dump(parse("define foo($a, $b) {}")).should == "(define foo (parameters a b) ())"
    end

    it "define foo($a, $b=10) {}" do
      dump(parse("define foo($a, $b=10) {}")).should == "(define foo (parameters a (= b 10)) ())"
    end

    it "define foo {$a = 10 $b = 20}" do
      dump(parse("define foo {$a = 10 $b = 20}")).should == [
        "(define foo (block",
        "  (= $a 10)",
        "  (= $b 20)",
        "))"
        ].join("\n")
    end

    context "it should handle '3x weirdness'" do
      it "define class {} # a define named 'class'" do
        # This is weird because Class already exists, and instantiating this define will probably not
        # work
        expect {
          dump(parse("define class {}")).should == "(define class ())"
          }.to raise_error(/not a valid classname/)
      end

      it "define default {} # a define named 'default'" do
        # Check unwanted ability to define 'default'.
        # The expression below is not allowed (which is good).
        #
        expect { dump(parse("define default {}")).should == "(define default ())"}.to raise_error(Puppet::ParseError)
      end
    end

    context 'it should allow keywords as attribute names' do
      ['and', 'case', 'class', 'default', 'define', 'else', 'elsif', 'if', 'in', 'inherits', 'node', 'or',
        'undef', 'unless', 'type', 'attr', 'function', 'private'].each do |keyword|
        it "such as #{keyword}" do
          expect {parse("define x ($#{keyword}){} x { y: #{keyword} => 1 }")}.to_not raise_error
        end
      end
    end
  end

  context "When parsing node" do
    it "node foo {}" do
      dump(parse("node foo {}")).should == "(node (matches 'foo') ())"
    end

    it "node foo, {} # trailing comma" do
      dump(parse("node foo, {}")).should == "(node (matches 'foo') ())"
    end

    it "node kermit.example.com {}" do
      dump(parse("node kermit.example.com {}")).should == "(node (matches 'kermit.example.com') ())"
    end

    it "node kermit . example . com {}" do
      dump(parse("node kermit . example . com {}")).should == "(node (matches 'kermit.example.com') ())"
    end

    it "node foo, x::bar, default {}" do
      dump(parse("node foo, x::bar, default {}")).should == "(node (matches 'foo' 'x::bar' :default) ())"
    end

    it "node 'foo' {}" do
      dump(parse("node 'foo' {}")).should == "(node (matches 'foo') ())"
    end

    it "node foo inherits x::bar {}" do
      dump(parse("node foo inherits x::bar {}")).should == "(node (matches 'foo') (parent 'x::bar') ())"
    end

    it "node foo inherits 'bar' {}" do
      dump(parse("node foo inherits 'bar' {}")).should == "(node (matches 'foo') (parent 'bar') ())"
    end

    it "node foo inherits default {}" do
      dump(parse("node foo inherits default {}")).should == "(node (matches 'foo') (parent :default) ())"
    end

    it "node /web.*/ {}" do
      dump(parse("node /web.*/ {}")).should == "(node (matches /web.*/) ())"
    end

    it "node /web.*/, /do\.wop.*/, and.so.on {}" do
      dump(parse("node /web.*/, /do\.wop.*/, 'and.so.on' {}")).should == "(node (matches /web.*/ /do\.wop.*/ 'and.so.on') ())"
    end

    it "node wat inherits /apache.*/ {}" do
      dump(parse("node wat inherits /apache.*/ {}")).should == "(node (matches 'wat') (parent /apache.*/) ())"
    end

    it "node foo inherits bar {$a = 10 $b = 20}" do
      dump(parse("node foo inherits bar {$a = 10 $b = 20}")).should == [
        "(node (matches 'foo') (parent 'bar') (block",
        "  (= $a 10)",
        "  (= $b 20)",
        "))"
        ].join("\n")
    end
  end
end
