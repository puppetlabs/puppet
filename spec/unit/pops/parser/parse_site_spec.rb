#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/parser_rspec_helper')

describe "egrammar parsing of site expression" do
  include ParserRspecHelper

  before(:each) do
    with_app_management(true)
  end

  after(:each) do
    with_app_management(false)
  end

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
