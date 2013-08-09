#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/parser_rspec_helper')

describe "egrammar parsing heredoc expressions" do
  include ParserRspecHelper

  context "using non dq style" do
    it "should parse heredoc without syntax spec" do
      dump(parse("$a =@(one)\ntext \none\n")).should == [
        "(= $a (@()", 
        "  'text \n'",
        "))"
        ].join("\n")
    end

    it "should parse heredoc with syntax spec and nl-right trim" do
      dump(parse("$a =@(one:puppish)\ntext \n-one\n")).should == [
        "(= $a (@(puppish)", 
        "  'text '", # does not trim trailing space, only newline
        "))"
        ].join("\n")
    end

    it "should parse heredoc with escape spec and right trim" do
      dump(parse("$a =@(one/tsrnL)\nt\\text\n-one\n")).should == [
        "(= $a (@()", 
        "  't\text'",
        "))"
        ].join("\n")
    end

    it "should fail parse heredoc with illegal escape spec" do
      expect {
        dump(parse("$a =@(one/tsrnLx)\nt\\text\n-one\n")).should == [
          "(= $a (@()", 
          "  't\text'",
          "))"
          ].join("\n")
      }.to raise_error(/Invalid heredoc escape char.*Got 'x'/)
    end

    it "should parse heredoc with syntax and escape spec and right trim" do
      dump(parse("$a =@(one:puppish/tsrnL)\nt\\text\n-one\n")).should == [
        "(= $a (@(puppish)", 
        "  't\text'",
        "))"
        ].join("\n")
    end
  end

  context "using dq style" do
    it "without syntax spec" do
      dump(parse("$a =@(\"one\")\ntex\\t \none\n")).should == [
        "(= $a (@()", 
        "  'tex\\t \n'",
        "))"
        ].join("\n")
    end

    it "with syntax spec and nl-right trim" do
      dump(parse("$a =@(\"one\":puppish)\ntext \n-one\n")).should == [
        "(= $a (@(puppish)", 
        "  'text '", # does not trim trailing space, only newline
        "))"
        ].join("\n")
    end

    it "with escape and nl-right trim" do
        dump(parse("$a =@(\"one\"/tsrnL)\nt\\text\n-one\n")).should == [
          "(= $a (@()", 
          "  't\text'",
          "))"
          ].join("\n")
    end

    it "with syntax and escape spec and nl-right trim" do
      dump(parse("$a =@(\"one\":puppish/tsrnL)\nt\\text\n-one\n")).should == [
        "(= $a (@(puppish)", 
        "  't\text'",
        "))"
        ].join("\n")
    end
    it "with interpolation and no escapes" do
      dump(parse("$x = foo $a =@(\"one\")\n$x \\$yay\n-one\n")).should == [
        "(block (= $x foo) (= $a (@()", 
        "  (cat '' (str $x) ' \\$yay')",
        ")))"
        ].join("\n")
    end
    it "with interpolation and all escapes" do
      dump(parse("$x = foo $a =@(\"one\"/)\n$x \\$yay\n-one\n")).should == [
        "(block (= $x foo) (= $a (@()", 
        "  (cat '' (str $x) ' $yay')",
        ")))"
        ].join("\n")
    end
  end
end
