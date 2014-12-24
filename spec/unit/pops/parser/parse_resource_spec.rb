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
        expect(dump(parse("#{word} { 'title': }"))).to eq([
          "(resource file",
          "  ('title'))"
        ].join("\n"))
      end

      it "#{word} { 'title': path => '/somewhere', mode => '0777'}" do
        expect(dump(parse("#{word} { 'title': path => '/somewhere', mode => '0777'}"))).to eq([
          "(resource file",
          "  ('title'",
          "    (path => '/somewhere')",
          "    (mode => '0777')))"
        ].join("\n"))
      end

      it "#{word} { 'title': path => '/somewhere', }" do
        expect(dump(parse("#{word} { 'title': path => '/somewhere', }"))).to eq([
          "(resource file",
          "  ('title'",
          "    (path => '/somewhere')))"
        ].join("\n"))
      end

      it "#{word} { 'title': , }" do
        expect(dump(parse("#{word} { 'title': , }"))).to eq([
          "(resource file",
          "  ('title'))"
        ].join("\n"))
      end

      it "#{word} { 'title': ; }" do
        expect(dump(parse("#{word} { 'title': ; }"))).to eq([
          "(resource file",
          "  ('title'))"
        ].join("\n"))
      end

      it "#{word} { 'title': ; 'other_title': }" do
        expect(dump(parse("#{word} { 'title': ; 'other_title': }"))).to eq([
          "(resource file",
          "  ('title')",
          "  ('other_title'))"
        ].join("\n"))
      end

      # PUP-2898, trailing ';'
      it "#{word} { 'title': ; 'other_title': ; }" do
        expect(dump(parse("#{word} { 'title': ; 'other_title': ; }"))).to eq([
          "(resource file",
          "  ('title')",
          "  ('other_title'))"
        ].join("\n"))
      end

      it "#{word} { 'title1': path => 'x'; 'title2': path => 'y'}" do
        expect(dump(parse("#{word} { 'title1': path => 'x'; 'title2': path => 'y'}"))).to eq([
          "(resource file",
          "  ('title1'",
          "    (path => 'x'))",
          "  ('title2'",
          "    (path => 'y')))",
        ].join("\n"))
      end

      it "#{word} { title: * => {mode => '0777'} }" do
        expect(dump(parse("#{word} { title: * => {mode => '0777'}}"))).to eq([
          "(resource file",
          "  (title",
          "    (* => ({} (mode '0777')))))"
        ].join("\n"))
      end
    end
  end

  context "When parsing (type based) resource defaults" do
    it "File {  }" do
      expect(dump(parse("File { }"))).to eq("(resource-defaults file)")
    end

    it "File { mode => '0777' }" do
      expect(dump(parse("File { mode => '0777'}"))).to eq([
        "(resource-defaults file",
        "  (mode => '0777'))"
      ].join("\n"))
    end

    it "File { * => {mode => '0777'} } (even if validated to be illegal)" do
      expect(dump(parse("File { * => {mode => '0777'}}"))).to eq([
        "(resource-defaults file",
        "  (* => ({} (mode '0777'))))"
      ].join("\n"))
    end
  end

  context "When parsing resource override" do
    it "File['x'] {  }" do
      expect(dump(parse("File['x'] { }"))).to eq("(override (slice file 'x'))")
    end

    it "File['x'] { x => 1 }" do
      expect(dump(parse("File['x'] { x => 1}"))).to eq([
        "(override (slice file 'x')",
        "  (x => 1))"
        ].join("\n"))
    end


    it "File['x', 'y'] { x => 1 }" do
      expect(dump(parse("File['x', 'y'] { x => 1}"))).to eq([
        "(override (slice file ('x' 'y'))",
        "  (x => 1))"
        ].join("\n"))
    end

    it "File['x'] { x => 1, y => 2 }" do
      expect(dump(parse("File['x'] { x => 1, y=> 2}"))).to eq([
        "(override (slice file 'x')",
        "  (x => 1)",
        "  (y => 2))"
        ].join("\n"))
    end

    it "File['x'] { x +> 1 }" do
      expect(dump(parse("File['x'] { x +> 1}"))).to eq([
        "(override (slice file 'x')",
        "  (x +> 1))"
        ].join("\n"))
    end

    it "File['x'] { * => {mode => '0777'} } (even if validated to be illegal)" do
      expect(dump(parse("File['x'] { * => {mode => '0777'}}"))).to eq([
        "(override (slice file 'x')",
        "  (* => ({} (mode '0777'))))"
      ].join("\n"))
    end
  end

  context "When parsing virtual and exported resources" do
    it "parses exported @@file { 'title': }" do
      expect(dump(parse("@@file { 'title': }"))).to eq("(exported-resource file\n  ('title'))")
    end

    it "parses virtual @file { 'title': }" do
      expect(dump(parse("@file { 'title': }"))).to eq("(virtual-resource file\n  ('title'))")
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
      expect(dump(parse("@File { mode => '0777' }"))).to eq([
        "(virtual-resource-defaults file",
        "  (mode => '0777'))"
        ].join("\n"))
    end

    it "parses global defaults with @@ (even if validated to be illegal)" do
      expect(dump(parse("@@File { mode => '0777' }"))).to eq([
        "(exported-resource-defaults file",
        "  (mode => '0777'))"
        ].join("\n"))
    end

    it "parses override with @ (even if validated to be illegal)" do
      expect(dump(parse("@File[foo] { mode => '0777' }"))).to eq([
        "(virtual-override (slice file foo)",
        "  (mode => '0777'))"
        ].join("\n"))
    end

    it "parses override combined with @@ (even if validated to be illegal)" do
      expect(dump(parse("@@File[foo] { mode => '0777' }"))).to eq([
        "(exported-override (slice file foo)",
        "  (mode => '0777'))"
        ].join("\n"))
    end
  end

  context "When parsing class resource" do
    it "class { 'cname': }" do
      expect(dump(parse("class { 'cname': }"))).to eq([
        "(resource class",
        "  ('cname'))"
      ].join("\n"))
    end

    it "@class { 'cname': }" do
      expect(dump(parse("@class { 'cname': }"))).to eq([
        "(virtual-resource class",
        "  ('cname'))"
      ].join("\n"))
    end

    it "@@class { 'cname': }" do
      expect(dump(parse("@@class { 'cname': }"))).to eq([
        "(exported-resource class",
        "  ('cname'))"
      ].join("\n"))
    end

    it "class { 'cname': x => 1, y => 2}" do
      expect(dump(parse("class { 'cname': x => 1, y => 2}"))).to eq([
        "(resource class",
        "  ('cname'",
        "    (x => 1)",
        "    (y => 2)))"
      ].join("\n"))
    end

    it "class { 'cname1': x => 1; 'cname2': y => 2}" do
      expect(dump(parse("class { 'cname1': x => 1; 'cname2': y => 2}"))).to eq([
        "(resource class",
        "  ('cname1'",
        "    (x => 1))",
        "  ('cname2'",
        "    (y => 2)))",
      ].join("\n"))
    end
  end

  context "reported issues in 3.x" do
    it "should not screw up on brackets in title of resource #19632" do
      expect(dump(parse('notify { "thisisa[bug]": }'))).to eq([
        "(resource notify",
        "  ('thisisa[bug]'))",
      ].join("\n"))
    end
  end

  context "When parsing Relationships" do
    it "File[a] -> File[b]" do
      expect(dump(parse("File[a] -> File[b]"))).to eq("(-> (slice file a) (slice file b))")
    end

    it "File[a] <- File[b]" do
      expect(dump(parse("File[a] <- File[b]"))).to eq("(<- (slice file a) (slice file b))")
    end

    it "File[a] ~> File[b]" do
      expect(dump(parse("File[a] ~> File[b]"))).to eq("(~> (slice file a) (slice file b))")
    end

    it "File[a] <~ File[b]" do
      expect(dump(parse("File[a] <~ File[b]"))).to eq("(<~ (slice file a) (slice file b))")
    end

    it "Should chain relationships" do
      expect(dump(parse("a -> b -> c"))).to eq(
      "(-> (-> a b) c)"
      )
    end

    it "Should chain relationships" do
      expect(dump(parse("File[a] -> File[b] ~> File[c] <- File[d] <~ File[e]"))).to eq(
      "(<~ (<- (~> (-> (slice file a) (slice file b)) (slice file c)) (slice file d)) (slice file e))"
      )
    end

    it "should create relationships between collects" do
      expect(dump(parse("File <| mode == 0644 |> -> File <| mode == 0755 |>"))).to eq(
      "(-> (collect file\n  (<| |> (== mode 0644))) (collect file\n  (<| |> (== mode 0755))))"
      )
    end
  end

  context "When parsing collection" do
    context "of virtual resources" do
      it "File <| |>" do
        expect(dump(parse("File <| |>"))).to eq("(collect file\n  (<| |>))")
      end
    end

    context "of exported resources" do
      it "File <<| |>>" do
        expect(dump(parse("File <<| |>>"))).to eq("(collect file\n  (<<| |>>))")
      end
    end

    context "queries are parsed with correct precedence" do
      it "File <| tag == 'foo' |>" do
        expect(dump(parse("File <| tag == 'foo' |>"))).to eq("(collect file\n  (<| |> (== tag 'foo')))")
      end

      it "File <| tag == 'foo' and mode != '0777' |>" do
        expect(dump(parse("File <| tag == 'foo' and mode != '0777' |>"))).to eq("(collect file\n  (<| |> (&& (== tag 'foo') (!= mode '0777'))))")
      end

      it "File <| tag == 'foo' or mode != '0777' |>" do
        expect(dump(parse("File <| tag == 'foo' or mode != '0777' |>"))).to eq("(collect file\n  (<| |> (|| (== tag 'foo') (!= mode '0777'))))")
      end

      it "File <| tag == 'foo' or tag == 'bar' and mode != '0777' |>" do
        expect(dump(parse("File <| tag == 'foo' or tag == 'bar' and mode != '0777' |>"))).to eq(
        "(collect file\n  (<| |> (|| (== tag 'foo') (&& (== tag 'bar') (!= mode '0777')))))"
        )
      end

      it "File <| (tag == 'foo' or tag == 'bar') and mode != '0777' |>" do
        expect(dump(parse("File <| (tag == 'foo' or tag == 'bar') and mode != '0777' |>"))).to eq(
        "(collect file\n  (<| |> (&& (|| (== tag 'foo') (== tag 'bar')) (!= mode '0777'))))"
        )
      end
    end
  end
end
