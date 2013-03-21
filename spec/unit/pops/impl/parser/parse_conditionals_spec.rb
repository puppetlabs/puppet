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

# Tests containers (top level in file = expr or a block), class, define, and node
describe Puppet::Pops::Impl::Parser::Parser do
  include ParserRspecHelper
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
      dump(parse("if true { $a = 10 $b = 20} else {$a = 20}")).should ==
      ["(if true",
        "  (then (block (= $a 10) (= $b 20)))",
        "  (else (= $a 20)))"].join("\n")
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
        "  (when (a) (then (block (= $b 10) (= $c 20)))))"
      ].join("\n")
    end
  end
  context "When parsing imports" do
    it "import 'foo'" do
      dump(parse("import 'foo'")).should == "(import 'foo')"
    end
    it "import 'foo', 'bar'" do
      dump(parse("import 'foo', 'bar'")).should == "(import 'foo' 'bar')"
    end
  end
end