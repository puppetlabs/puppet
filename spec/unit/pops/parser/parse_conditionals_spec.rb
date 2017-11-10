#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/parser_rspec_helper')

describe "egrammar parsing conditionals" do
  include ParserRspecHelper

  context "When parsing if statements" do
    it "if true { $a = 10 }" do
      expect(dump(parse("if true { $a = 10 }"))).to eq("(if true\n  (then (= $a 10)))")
    end

    it "if true { $a = 10 } else {$a = 20}" do
      expect(dump(parse("if true { $a = 10 } else {$a = 20}"))).to eq(
      ["(if true",
        "  (then (= $a 10))",
        "  (else (= $a 20)))"].join("\n")
      )
    end

    it "if true { $a = 10 } elsif false { $a = 15} else {$a = 20}" do
      expect(dump(parse("if true { $a = 10 } elsif false { $a = 15} else {$a = 20}"))).to eq(
      ["(if true",
        "  (then (= $a 10))",
        "  (else (if false",
        "      (then (= $a 15))",
        "      (else (= $a 20)))))"].join("\n")
      )
    end

    it "if true { $a = 10 $b = 10 } else {$a = 20}" do
      expect(dump(parse("if true { $a = 10 $b = 20} else {$a = 20}"))).to eq([
       "(if true",
       "  (then (block",
       "      (= $a 10)",
       "      (= $b 20)",
       "    ))",
       "  (else (= $a 20)))"
       ].join("\n"))
    end

    it "allows a parenthesized conditional expression" do
      expect(dump(parse("if (true) { 10 }"))).to eq("(if true\n  (then 10))")
    end

    it "allows a parenthesized elsif conditional expression" do
      expect(dump(parse("if true { 10 } elsif (false) { 20 }"))).to eq(
        ["(if true",
         "  (then 10)",
         "  (else (if false",
         "      (then 20))))"].join("\n")
      )
    end
  end

  context "When parsing unless statements" do
    it "unless true { $a = 10 }" do
      expect(dump(parse("unless true { $a = 10 }"))).to eq("(unless true\n  (then (= $a 10)))")
    end

    it "unless true { $a = 10 } else {$a = 20}" do
      expect(dump(parse("unless true { $a = 10 } else {$a = 20}"))).to eq(
      ["(unless true",
        "  (then (= $a 10))",
        "  (else (= $a 20)))"].join("\n")
      )
    end

    it "allows a parenthesized conditional expression" do
      expect(dump(parse("unless (true) { 10 }"))).to eq("(unless true\n  (then 10))")
    end

    it "unless true { $a = 10 } elsif false { $a = 15} else {$a = 20} # is illegal" do
      expect { parse("unless true { $a = 10 } elsif false { $a = 15} else {$a = 20}")}.to raise_error(Puppet::ParseError)
    end
  end

  context "When parsing selector expressions" do
    it "$a = $b ? banana => fruit " do
      expect(dump(parse("$a = $b ? banana => fruit"))).to eq(
      "(= $a (? $b (banana => fruit)))"
      )
    end

    it "$a = $b ? { banana => fruit}" do
      expect(dump(parse("$a = $b ? { banana => fruit }"))).to eq(
      "(= $a (? $b (banana => fruit)))"
      )
    end

    it "does not fail on a trailing blank line" do
      expect(dump(parse("$a = $b ? { banana => fruit }\n\n"))).to eq(
      "(= $a (? $b (banana => fruit)))"
      )
    end

    it "$a = $b ? { banana => fruit, grape => berry }" do
      expect(dump(parse("$a = $b ? {banana => fruit, grape => berry}"))).to eq(
      "(= $a (? $b (banana => fruit) (grape => berry)))"
      )
    end

    it "$a = $b ? { banana => fruit, grape => berry, default => wat }" do
      expect(dump(parse("$a = $b ? {banana => fruit, grape => berry, default => wat}"))).to eq(
      "(= $a (? $b (banana => fruit) (grape => berry) (:default => wat)))"
      )
    end

    it "$a = $b ? { default => wat, banana => fruit, grape => berry,  }" do
      expect(dump(parse("$a = $b ? {default => wat, banana => fruit, grape => berry}"))).to eq(
      "(= $a (? $b (:default => wat) (banana => fruit) (grape => berry)))"
      )
    end

    it '1+2 ? 3 => yes' do
      expect(dump(parse("1+2 ? 3 => yes"))).to eq(
      "(? (+ 1 2) (3 => yes))"
      )
    end

    it 'true and 1+2 ? 3 => yes' do
      expect(dump(parse("true and 1+2 ? 3 => yes"))).to eq(
      "(&& true (? (+ 1 2) (3 => yes)))"
      )
    end
  end

  context "When parsing case statements" do
    it "case $a { a : {}}" do
      expect(dump(parse("case $a { a : {}}"))).to eq(
      ["(case $a",
        "  (when (a) (then ())))"
      ].join("\n")
      )
    end

    it "allows a parenthesized value expression" do
      expect(dump(parse("case ($a) { a : {}}"))).to eq(
      ["(case $a",
        "  (when (a) (then ())))"
      ].join("\n")
      )
    end

    it "case $a { /.*/ : {}}" do
      expect(dump(parse("case $a { /.*/ : {}}"))).to eq(
      ["(case $a",
        "  (when (/.*/) (then ())))"
      ].join("\n")
      )
    end

    it "case $a { a, b : {}}" do
      expect(dump(parse("case $a { a, b : {}}"))).to eq(
      ["(case $a",
        "  (when (a b) (then ())))"
      ].join("\n")
      )
    end

    it "case $a { a, b : {} default : {}}" do
      expect(dump(parse("case $a { a, b : {} default : {}}"))).to eq(
      ["(case $a",
        "  (when (a b) (then ()))",
        "  (when (:default) (then ())))"
      ].join("\n")
      )
    end

    it "case $a { a : {$b = 10 $c = 20}}" do
      expect(dump(parse("case $a { a : {$b = 10 $c = 20}}"))).to eq(
      ["(case $a",
       "  (when (a) (then (block",
       "    (= $b 10)",
       "    (= $c 20)",
       "  ))))"
      ].join("\n")
      )
    end
  end

end
