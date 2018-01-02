#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require_relative 'parser_rspec_helper'

describe "egrammar parsing of 'plan'" do
  include ParserRspecHelper

  context 'with --tasks' do
    before(:each) do
      Puppet[:tasks] = true
    end

    it "an empty body" do
      expect(dump(parse("plan foo { }"))).to eq("(plan foo ())")
    end

    it "a non empty body" do
      prog = <<-EPROG
  plan foo {
    $a = 10
    $b = 20
  }
  EPROG
      expect(dump(parse(prog))).to eq( [
  "(plan foo (block",
  "  (= $a 10)",
  "  (= $b 20)",
  "))",
  ].join("\n"))
    end

    it "accepts parameters" do
      s = "plan foo($p1 = 'yo', $p2) { }"
      expect(dump(parse(s))).to eq("(plan foo (parameters (= p1 'yo') p2) ())")
    end
  end

  context 'with --no-tasks' do
    before(:each) do
      Puppet[:tasks] = false
    end

    it "the keyword 'plan' is a name" do
      expect(dump(parse("$a = plan"))).to eq("(= $a plan)")
    end
  end
end
