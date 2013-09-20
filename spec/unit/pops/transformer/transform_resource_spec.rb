#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/transformer_rspec_helper')

describe "transformation to Puppet AST for resource declarations" do
  include TransformerRspecHelper

  context "When transforming regular resource" do
    it "file { 'title': }" do
      astdump(parse("file { 'title': }")).should == [
        "(resource file",
        "  ('title'))"
      ].join("\n")
    end

    it "file { 'title': ; 'other_title': }" do
      astdump(parse("file { 'title': ; 'other_title': }")).should == [
        "(resource file",
        "  ('title')",
        "  ('other_title'))"
      ].join("\n")
    end

    it "file { 'title': path => '/somewhere', mode => 0777}" do
      astdump(parse("file { 'title': path => '/somewhere', mode => 0777}")).should == [
        "(resource file",
        "  ('title'",
        "    (path => '/somewhere')",
        "    (mode => 0777)))"
      ].join("\n")
    end

    it "file { 'title1': path => 'x'; 'title2': path => 'y'}" do
      astdump(parse("file { 'title1': path => 'x'; 'title2': path => 'y'}")).should == [
        "(resource file",
        "  ('title1'",
        "    (path => 'x'))",
        "  ('title2'",
        "    (path => 'y')))",
      ].join("\n")
    end
  end

  context "When transforming resource defaults" do
    it "File {  }" do
      astdump(parse("File { }")).should == "(resource-defaults file)"
    end

    it "File { mode => 0777 }" do
      astdump(parse("File { mode => 0777}")).should == [
        "(resource-defaults file",
        "  (mode => 0777))"
      ].join("\n")
    end
  end

  context "When transforming resource override" do
    it "File['x'] {  }" do
      astdump(parse("File['x'] { }")).should == "(override (slice file 'x'))"
    end

    it "File['x'] { x => 1 }" do
      astdump(parse("File['x'] { x => 1}")).should == "(override (slice file 'x')\n  (x => 1))"
    end

    it "File['x', 'y'] { x => 1 }" do
      astdump(parse("File['x', 'y'] { x => 1}")).should == "(override (slice file ('x' 'y'))\n  (x => 1))"
    end

    it "File['x'] { x => 1, y => 2 }" do
      astdump(parse("File['x'] { x => 1, y=> 2}")).should == "(override (slice file 'x')\n  (x => 1)\n  (y => 2))"
    end

    it "File['x'] { x +> 1 }" do
      astdump(parse("File['x'] { x +> 1}")).should == "(override (slice file 'x')\n  (x +> 1))"
    end
  end

  context "When transforming virtual and exported resources" do
    it "@@file { 'title': }" do
      astdump(parse("@@file { 'title': }")).should ==  "(exported-resource file\n  ('title'))"
    end

    it "@file { 'title': }" do
      astdump(parse("@file { 'title': }")).should ==  "(virtual-resource file\n  ('title'))"
    end
  end

  context "When transforming class resource" do
    it "class { 'cname': }" do
      astdump(parse("class { 'cname': }")).should == [
        "(resource class",
        "  ('cname'))"
      ].join("\n")
    end

    it "class { 'cname': x => 1, y => 2}" do
      astdump(parse("class { 'cname': x => 1, y => 2}")).should == [
        "(resource class",
        "  ('cname'",
        "    (x => 1)",
        "    (y => 2)))"
      ].join("\n")
    end

    it "class { 'cname1': x => 1; 'cname2': y => 2}" do
      astdump(parse("class { 'cname1': x => 1; 'cname2': y => 2}")).should == [
        "(resource class",
        "  ('cname1'",
        "    (x => 1))",
        "  ('cname2'",
        "    (y => 2)))",
      ].join("\n")
    end
  end

  context "When transforming Relationships" do
    it "File[a] -> File[b]" do
      astdump(parse("File[a] -> File[b]")).should == "(-> (slice file a) (slice file b))"
    end

    it "File[a] <- File[b]" do
      astdump(parse("File[a] <- File[b]")).should == "(<- (slice file a) (slice file b))"
    end

    it "File[a] ~> File[b]" do
      astdump(parse("File[a] ~> File[b]")).should == "(~> (slice file a) (slice file b))"
    end

    it "File[a] <~ File[b]" do
      astdump(parse("File[a] <~ File[b]")).should == "(<~ (slice file a) (slice file b))"
    end

    it "Should chain relationships" do
      astdump(parse("a -> b -> c")).should ==
      "(-> (-> a b) c)"
    end

    it "Should chain relationships" do
      astdump(parse("File[a] -> File[b] ~> File[c] <- File[d] <~ File[e]")).should ==
      "(<~ (<- (~> (-> (slice file a) (slice file b)) (slice file c)) (slice file d)) (slice file e))"
    end
  end

  context "When transforming collection" do
    context "of virtual resources" do
      it "File <| |>" do
        astdump(parse("File <| |>")).should == "(collect file\n  (<| |>))"
      end
    end

    context "of exported resources" do
      it "File <<| |>>" do
        astdump(parse("File <<| |>>")).should == "(collect file\n  (<<| |>>))"
      end
    end

    context "queries are parsed with correct precedence" do
      it "File <| tag == 'foo' |>" do
        astdump(parse("File <| tag == 'foo' |>")).should == "(collect file\n  (<| |> (== tag 'foo')))"
      end

      it "File <| tag == 'foo' and mode != 0777 |>" do
        astdump(parse("File <| tag == 'foo' and mode != 0777 |>")).should == "(collect file\n  (<| |> (&& (== tag 'foo') (!= mode 0777))))"
      end

      it "File <| tag == 'foo' or mode != 0777 |>" do
        astdump(parse("File <| tag == 'foo' or mode != 0777 |>")).should == "(collect file\n  (<| |> (|| (== tag 'foo') (!= mode 0777))))"
      end

      it "File <| tag == 'foo' or tag == 'bar' and mode != 0777 |>" do
        astdump(parse("File <| tag == 'foo' or tag == 'bar' and mode != 0777 |>")).should ==
        "(collect file\n  (<| |> (|| (== tag 'foo') (&& (== tag 'bar') (!= mode 0777)))))"
      end

      it "File <| (tag == 'foo' or tag == 'bar') and mode != 0777 |>" do
        astdump(parse("File <| (tag == 'foo' or tag == 'bar') and mode != 0777 |>")).should ==
        "(collect file\n  (<| |> (&& (|| (== tag 'foo') (== tag 'bar')) (!= mode 0777))))"
      end
    end
  end
end
