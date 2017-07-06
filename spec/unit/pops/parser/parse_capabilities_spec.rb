#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require_relative 'parser_rspec_helper'

describe "egrammar parsing of capability mappings" do
  include ParserRspecHelper

  before(:each) { Puppet[:app_management] = true }
  after(:each) { Puppet[:app_management] = false }

  context "when parsing 'produces'" do
    it "the ast contains produces and attributes" do
      prog = "Foo produces Sql { name => value }"
      ast = "(produces Foo Sql ((name => value)))"
      expect(dump(parse(prog))).to eq(ast)
    end

    it "optional end comma is allowed" do
      prog = "Foo produces Sql { name => value, }"
      ast = "(produces Foo Sql ((name => value)))"
      expect(dump(parse(prog))).to eq(ast)
    end
  end

  context "when parsing 'consumes'" do
    it "the ast contains consumes and attributes" do
      prog = "Foo consumes Sql { name => value }"
      ast = "(consumes Foo Sql ((name => value)))"
      expect(dump(parse(prog))).to eq(ast)
    end

    it "optional end comma is allowed" do
      prog = "Foo consumes Sql { name => value, }"
      ast = "(consumes Foo Sql ((name => value)))"
      expect(dump(parse(prog))).to eq(ast)
    end

  end
end
