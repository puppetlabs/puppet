#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/parser_rspec_helper')

describe "egrammar parsing conditionals" do
  include ParserRspecHelper

  context "When parsing if statements" do
    it "if true { $a = 10 }" do
      dump(parse("if true { $a = 10 }")).should == "(if true\n  (then (= $a 10)))"
    end

    it "if true { $a = 10 } else {$a = 20}" do
      dump(parse("if true { $a = 10 } else {$a = 20}")).should ==
      ["(if true",
        "  (then (= $a 10))",
        "  (else (= $a 20)))"].join("\n")
    end

    it "if true { $a = 10 } elsif false { $a = 15} else {$a = 20}" do
      dump(parse("if true { $a = 10 } elsif false { $a = 15} else {$a = 20}")).should ==
      ["(if true",
        "  (then (= $a 10))",
        "  (else (if false",
        "      (then (= $a 15))",
        "      (else (= $a 20)))))"].join("\n")
    end

    it "if true { $a = 10 $b = 10 } else {$a = 20}" do
      dump(parse("if true { $a = 10 $b = 20} else {$a = 20}")).should == [
       "(if true",
       "  (then (block",
       "      (= $a 10)",
       "      (= $b 20)",
       "    ))",
       "  (else (= $a 20)))"
       ].join("\n")
    end

    it "allows a parenthesized conditional expression" do
      dump(parse("if (true) { 10 }")).should == "(if true\n  (then 10))"
    end

    it "allows a parenthesized elsif conditional expression" do
      dump(parse("if true { 10 } elsif (false) { 20 }")).should ==
        ["(if true",
         "  (then 10)",
         "  (else (if false",
         "      (then 20))))"].join("\n")
    end
  end

  context "When parsing unless statements" do
    it "unless true { $a = 10 }" do
      dump(parse("unless true { $a = 10 }")).should == "(unless true\n  (then (= $a 10)))"
    end

    it "unless true { $a = 10 } else {$a = 20}" do
      dump(parse("unless true { $a = 10 } else {$a = 20}")).should ==
      ["(unless true",
        "  (then (= $a 10))",
        "  (else (= $a 20)))"].join("\n")
    end

    it "allows a parenthesized conditional expression" do
      dump(parse("unless (true) { 10 }")).should == "(unless true\n  (then 10))"
    end

    it "unless true { $a = 10 } elsif false { $a = 15} else {$a = 20} # is illegal" do
      expect { parse("unless true { $a = 10 } elsif false { $a = 15} else {$a = 20}")}.to raise_error(Puppet::ParseError)
    end
  end

  context "When parsing selector expressions" do
    it "$a = $b ? banana => fruit " do
      dump(parse("$a = $b ? banana => fruit")).should ==
      "(= $a (? $b (banana => fruit)))"
    end

    it "$a = $b ? { banana => fruit}" do
      dump(parse("$a = $b ? { banana => fruit }")).should ==
      "(= $a (? $b (banana => fruit)))"
    end

    it "does not fail on a trailing blank line" do
      dump(parse("$a = $b ? { banana => fruit }\n\n")).should ==
      "(= $a (? $b (banana => fruit)))"
    end

    it "$a = $b ? { banana => fruit, grape => berry }" do
      dump(parse("$a = $b ? {banana => fruit, grape => berry}")).should ==
      "(= $a (? $b (banana => fruit) (grape => berry)))"
    end

    it "$a = $b ? { banana => fruit, grape => berry, default => wat }" do
      dump(parse("$a = $b ? {banana => fruit, grape => berry, default => wat}")).should ==
      "(= $a (? $b (banana => fruit) (grape => berry) (:default => wat)))"
    end

    it "$a = $b ? { default => wat, banana => fruit, grape => berry,  }" do
      dump(parse("$a = $b ? {default => wat, banana => fruit, grape => berry}")).should ==
      "(= $a (? $b (:default => wat) (banana => fruit) (grape => berry)))"
    end
  end

  context "When parsing case statements" do
    it "case $a { a : {}}" do
      dump(parse("case $a { a : {}}")).should ==
      ["(case $a",
        "  (when (a) (then ())))"
      ].join("\n")
    end

    it "allows a parenthesized value expression" do
      dump(parse("case ($a) { a : {}}")).should ==
      ["(case $a",
        "  (when (a) (then ())))"
      ].join("\n")
    end

    it "case $a { /.*/ : {}}" do
      dump(parse("case $a { /.*/ : {}}")).should ==
      ["(case $a",
        "  (when (/.*/) (then ())))"
      ].join("\n")
    end

    it "case $a { a, b : {}}" do
      dump(parse("case $a { a, b : {}}")).should ==
      ["(case $a",
        "  (when (a b) (then ())))"
      ].join("\n")
    end

    it "case $a { a, b : {} default : {}}" do
      dump(parse("case $a { a, b : {} default : {}}")).should ==
      ["(case $a",
        "  (when (a b) (then ()))",
        "  (when (:default) (then ())))"
      ].join("\n")
    end

    it "case $a { a : {$b = 10 $c = 20}}" do
      dump(parse("case $a { a : {$b = 10 $c = 20}}")).should ==
      ["(case $a",
       "  (when (a) (then (block",
       "    (= $b 10)",
       "    (= $c 20)",
       "  ))))"
      ].join("\n")
    end
  end

end
