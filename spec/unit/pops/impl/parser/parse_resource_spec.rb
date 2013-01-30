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

# Tests resource parsing.
# @todo Add more tests for variations on end comma and end semicolon.
# @todo Add tests for related syntax parse errors
#  
describe Puppet::Pops::Impl::Parser::Parser do

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

  context "When parsing regular resource" do
    it "file { 'title': }" do
      dump(parse("file { 'title': }")).should == [
        "(resource file",
        "  ('title'))"
        ].join("\n")
      end
    it "file { 'title': path => '/somewhere', mode => 0777}" do
      dump(parse("file { 'title': path => '/somewhere', mode => 0777}")).should == [
        "(resource file",
        "  ('title'",
        "    (path => '/somewhere')",
        "    (mode => 0777)))"
        ].join("\n")
      end
    it "file { 'title1': path => 'x'; 'title2': path => 'y'}" do
      dump(parse("file { 'title1': path => 'x'; 'title2': path => 'y'}")).should == [
        "(resource file",
        "  ('title1'",
        "    (path => 'x'))",
        "  ('title2'",
        "    (path => 'y')))",
        ].join("\n")
    end
  end
  context "When parsing resource defaults" do
    it "File {  }" do
      dump(parse("File { }")).should == "(resource-defaults file)"
    end
    it "File { mode => 0777 }" do
      dump(parse("File { mode => 0777}")).should == [
        "(resource-defaults file",
        "  (mode => 0777))"
        ].join("\n")
      end
  end

  context "When parsing resource override" do
    it "File['x'] {  }" do
      dump(parse("File['x'] { }")).should == "(override (slice file 'x'))"
    end
    it "File['x'] { x => 1 }" do
      dump(parse("File['x'] { x => 1}")).should == "(override (slice file 'x')\n  (x => 1))"
    end
    it "File['x'] { x => 1, y => 2 }" do
      dump(parse("File['x'] { x => 1, y=> 2}")).should == "(override (slice file 'x')\n  (x => 1)\n  (y => 2))"
    end
    it "File['x'] { x +> 1 }" do
      dump(parse("File['x'] { x +> 1}")).should == "(override (slice file 'x')\n  (x +> 1))"
    end
  end

  context "When parsing virtual and exported resources" do
    it "@@file { 'title': }" do
      dump(parse("@@file { 'title': }")).should ==  "(exported-resource file\n  ('title'))"
    end
    it "@file { 'title': }" do
      dump(parse("@file { 'title': }")).should ==  "(virtual-resource file\n  ('title'))"
    end
  end
  
  context "When parsing class resource" do
    it "class { 'cname': }" do
      dump(parse("class { 'cname': }")).should == [
        "(resource class",
        "  ('cname'))"
        ].join("\n")
      end
    it "class { 'cname': x => 1, y => 2}" do
      dump(parse("class { 'cname': x => 1, y => 2}")).should == [
        "(resource class",
        "  ('cname'",
        "    (x => 1)",
        "    (y => 2)))"
        ].join("\n")
      end
    it "class { 'cname1': x => 1; 'cname2': y => 2}" do
      dump(parse("class { 'cname1': x => 1; 'cname2': y => 2}")).should == [
        "(resource class",
        "  ('cname1'",
        "    (x => 1))",
        "  ('cname2'",
        "    (y => 2)))",
        ].join("\n")
      end
    end

  context "When parsing collection" do
    context "of virtual resources" do
      it "File <| |>" do
        dump(parse("File <| |>")).should == "(collect file\n  (<| |>))"
      end
    end
    context "of exported resources" do
      it "File <<| |>>" do
        dump(parse("File <<| |>>")).should == "(collect file\n  (<<| |>>))"
      end
    end
    context "queries are parsed with correct precedence" do
      it "File <| tag == 'foo' |>" do
        dump(parse("File <| tag == 'foo' |>")).should == "(collect file\n  (<| |> (== tag 'foo')))"
      end
      it "File <| tag == 'foo' and mode != 0777 |>" do
        dump(parse("File <| tag == 'foo' and mode != 0777 |>")).should == "(collect file\n  (<| |> (&& (== tag 'foo') (!= mode 0777))))"
      end
      it "File <| tag == 'foo' or mode != 0777 |>" do
        dump(parse("File <| tag == 'foo' or mode != 0777 |>")).should == "(collect file\n  (<| |> (|| (== tag 'foo') (!= mode 0777))))"
      end
      it "File <| tag == 'foo' or tag == 'bar' and mode != 0777 |>" do
        dump(parse("File <| tag == 'foo' or tag == 'bar' and mode != 0777 |>")).should == 
          "(collect file\n  (<| |> (|| (== tag 'foo') (&& (== tag 'bar') (!= mode 0777)))))"
      end
      it "File <| (tag == 'foo' or tag == 'bar') and mode != 0777 |>" do
        dump(parse("File <| (tag == 'foo' or tag == 'bar') and mode != 0777 |>")).should == 
          "(collect file\n  (<| |> (&& (|| (== tag 'foo') (== tag 'bar')) (!= mode 0777))))"
      end
    end
  end
end