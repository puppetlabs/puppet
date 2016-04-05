#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require_relative 'parser_rspec_helper'

describe "egrammar parsing of site expression" do
  include ParserRspecHelper

  before(:each) { Puppet[:app_management] = true }
  after(:each) { Puppet[:app_management] = false }

  context "when parsing 'site'" do
    it "an empty body is allowed" do
      prog = "site { }"
      ast = "(site ())"
      expect(dump(parse(prog))).to eq(ast)
    end

    it "a body with one expression is allowed" do
      prog = "site { $x = 1 }"
      ast = "(site (block\n  (= $x 1)\n))"
      expect(dump(parse(prog))).to eq(ast)
    end

    it "a body with more than one expression is allowed" do
      prog = "site { $x = 1 $y = 2}"
      ast = "(site (block\n  (= $x 1)\n  (= $y 2)\n))"
      expect(dump(parse(prog))).to eq(ast)
    end
  end
end
