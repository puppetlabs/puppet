#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/parser_rspec_helper')

describe "egrammar parsing resource declarations" do
  include ParserRspecHelper

  context "When parsing regular resource" do
    ["File", "file"].each do |word|
      it "#{word} { 'title': }" do
        dump(parse("#{word} { 'title': }")).should == [
          "(resource file",
          "  ('title'))"
        ].join("\n")
      end

      it "#{word} { 'title': path => '/somewhere', mode => '0777'}" do
        dump(parse("#{word} { 'title': path => '/somewhere', mode => '0777'}")).should == [
          "(resource file",
          "  ('title'",
          "    (path => '/somewhere')",
          "    (mode => '0777')))"
        ].join("\n")
      end

      it "#{word} { 'title': path => '/somewhere', }" do
        dump(parse("#{word} { 'title': path => '/somewhere', }")).should == [
          "(resource file",
          "  ('title'",
          "    (path => '/somewhere')))"
        ].join("\n")
      end

      it "#{word} { 'title': , }" do
        dump(parse("#{word} { 'title': , }")).should == [
          "(resource file",
          "  ('title'))"
        ].join("\n")
      end

      it "#{word} { 'title': ; }" do
        dump(parse("#{word} { 'title': ; }")).should == [
          "(resource file",
          "  ('title'))"
        ].join("\n")
      end

      it "#{word} { 'title': ; 'other_title': }" do
        dump(parse("#{word} { 'title': ; 'other_title': }")).should == [
          "(resource file",
          "  ('title')",
          "  ('other_title'))"
        ].join("\n")
      end

      # PUP-2898, trailing ';'
      it "#{word} { 'title': ; 'other_title': ; }" do
        dump(parse("#{word} { 'title': ; 'other_title': ; }")).should == [
          "(resource file",
          "  ('title')",
          "  ('other_title'))"
        ].join("\n")
      end

      it "#{word} { 'title1': path => 'x'; 'title2': path => 'y'}" do
        dump(parse("#{word} { 'title1': path => 'x'; 'title2': path => 'y'}")).should == [
          "(resource file",
          "  ('title1'",
          "    (path => 'x'))",
          "  ('title2'",
          "    (path => 'y')))",
        ].join("\n")
      end

      it "#{word} { title: * => {mode => '0777'} }" do
        dump(parse("#{word} { title: * => {mode => '0777'}}")).should == [
          "(resource file",
          "  (title",
          "    (* => ({} (mode '0777')))))"
        ].join("\n")
      end
    end
  end

  context "When parsing (type based) resource defaults" do
    it "File {  }" do
      dump(parse("File { }")).should == "(resource-defaults file)"
    end

    it "File { mode => '0777' }" do
      dump(parse("File { mode => '0777'}")).should == [
        "(resource-defaults file",
        "  (mode => '0777'))"
      ].join("\n")
    end

    it "File { * => {mode => '0777'} } (even if validated to be illegal)" do
      dump(parse("File { * => {mode => '0777'}}")).should == [
        "(resource-defaults file",
        "  (* => ({} (mode '0777'))))"
      ].join("\n")
    end
  end

  context "When parsing resource override" do
    it "File['x'] {  }" do
      dump(parse("File['x'] { }")).should == "(override (slice file 'x'))"
    end

    it "File['x'] { x => 1 }" do
      dump(parse("File['x'] { x => 1}")).should == [
        "(override (slice file 'x')",
        "  (x => 1))"
        ].join("\n")
    end


    it "File['x', 'y'] { x => 1 }" do
      dump(parse("File['x', 'y'] { x => 1}")).should == [
        "(override (slice file ('x' 'y'))",
        "  (x => 1))"
        ].join("\n")
    end

    it "File['x'] { x => 1, y => 2 }" do
      dump(parse("File['x'] { x => 1, y=> 2}")).should == [
        "(override (slice file 'x')",
        "  (x => 1)",
        "  (y => 2))"
        ].join("\n")
    end

    it "File['x'] { x +> 1 }" do
      dump(parse("File['x'] { x +> 1}")).should == [
        "(override (slice file 'x')",
        "  (x +> 1))"
        ].join("\n")
    end

    it "File['x'] { * => {mode => '0777'} } (even if validated to be illegal)" do
      dump(parse("File['x'] { * => {mode => '0777'}}")).should == [
        "(override (slice file 'x')",
        "  (* => ({} (mode '0777'))))"
      ].join("\n")
    end
  end

  context "When parsing virtual and exported resources" do
    it "parses exported @@file { 'title': }" do
      dump(parse("@@file { 'title': }")).should ==  "(exported-resource file\n  ('title'))"
    end

    it "parses virtual @file { 'title': }" do
      dump(parse("@file { 'title': }")).should ==  "(virtual-resource file\n  ('title'))"
    end

    it "nothing before the title colon is a syntax error" do
      expect do
        parse("@file {: mode => '0777' }")
      end.to raise_error(/Syntax error/)
    end

    it "raises error for user error; not a resource" do
      # The expression results in VIRTUAL, CALL FUNCTION('file', HASH) since the resource body has
      # no title.
      expect do
        parse("@file { mode => '0777' }")
      end.to raise_error(/Virtual \(@\) can only be applied to a Resource Expression/)
    end

    it "parses global defaults with @ (even if validated to be illegal)" do
      dump(parse("@File { mode => '0777' }")).should == [
        "(virtual-resource-defaults file",
        "  (mode => '0777'))"
        ].join("\n")
    end

    it "parses global defaults with @@ (even if validated to be illegal)" do
      dump(parse("@@File { mode => '0777' }")).should == [
        "(exported-resource-defaults file",
        "  (mode => '0777'))"
        ].join("\n")
    end

    it "parses override with @ (even if validated to be illegal)" do
      dump(parse("@File[foo] { mode => '0777' }")).should == [
        "(virtual-override (slice file foo)",
        "  (mode => '0777'))"
        ].join("\n")
    end

    it "parses override combined with @@ (even if validated to be illegal)" do
      dump(parse("@@File[foo] { mode => '0777' }")).should == [
        "(exported-override (slice file foo)",
        "  (mode => '0777'))"
        ].join("\n")
    end
  end

  context "When parsing class resource" do
    it "class { 'cname': }" do
      dump(parse("class { 'cname': }")).should == [
        "(resource class",
        "  ('cname'))"
      ].join("\n")
    end

    it "@class { 'cname': }" do
      dump(parse("@class { 'cname': }")).should == [
        "(virtual-resource class",
        "  ('cname'))"
      ].join("\n")
    end

    it "@@class { 'cname': }" do
      dump(parse("@@class { 'cname': }")).should == [
        "(exported-resource class",
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

  context "reported issues in 3.x" do
    it "should not screw up on brackets in title of resource #19632" do
      dump(parse('notify { "thisisa[bug]": }')).should == [
        "(resource notify",
        "  ('thisisa[bug]'))",
      ].join("\n")
    end
  end

  context "When parsing Relationships" do
    it "File[a] -> File[b]" do
      dump(parse("File[a] -> File[b]")).should == "(-> (slice file a) (slice file b))"
    end

    it "File[a] <- File[b]" do
      dump(parse("File[a] <- File[b]")).should == "(<- (slice file a) (slice file b))"
    end

    it "File[a] ~> File[b]" do
      dump(parse("File[a] ~> File[b]")).should == "(~> (slice file a) (slice file b))"
    end

    it "File[a] <~ File[b]" do
      dump(parse("File[a] <~ File[b]")).should == "(<~ (slice file a) (slice file b))"
    end

    it "Should chain relationships" do
      dump(parse("a -> b -> c")).should ==
      "(-> (-> a b) c)"
    end

    it "Should chain relationships" do
      dump(parse("File[a] -> File[b] ~> File[c] <- File[d] <~ File[e]")).should ==
      "(<~ (<- (~> (-> (slice file a) (slice file b)) (slice file c)) (slice file d)) (slice file e))"
    end

    it "should create relationships between collects" do
      dump(parse("File <| mode == 0644 |> -> File <| mode == 0755 |>")).should ==
      "(-> (collect file\n  (<| |> (== mode 0644))) (collect file\n  (<| |> (== mode 0755))))"
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

      it "File <| tag == 'foo' and mode != '0777' |>" do
        dump(parse("File <| tag == 'foo' and mode != '0777' |>")).should == "(collect file\n  (<| |> (&& (== tag 'foo') (!= mode '0777'))))"
      end

      it "File <| tag == 'foo' or mode != '0777' |>" do
        dump(parse("File <| tag == 'foo' or mode != '0777' |>")).should == "(collect file\n  (<| |> (|| (== tag 'foo') (!= mode '0777'))))"
      end

      it "File <| tag == 'foo' or tag == 'bar' and mode != '0777' |>" do
        dump(parse("File <| tag == 'foo' or tag == 'bar' and mode != '0777' |>")).should ==
        "(collect file\n  (<| |> (|| (== tag 'foo') (&& (== tag 'bar') (!= mode '0777')))))"
      end

      it "File <| (tag == 'foo' or tag == 'bar') and mode != '0777' |>" do
        dump(parse("File <| (tag == 'foo' or tag == 'bar') and mode != '0777' |>")).should ==
        "(collect file\n  (<| |> (&& (|| (== tag 'foo') (== tag 'bar')) (!= mode '0777'))))"
      end
    end
  end
end
