#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require_relative 'parser_rspec_helper'

describe "egrammar parsing of 'application'" do
  include ParserRspecHelper

  before(:each) { Puppet[:app_management] = true }
  after(:each) { Puppet[:app_management] = false }

  it "an empty body" do
    expect(dump(parse("application foo { }"))).to eq("(application foo () ())")
  end

  it "an empty body" do
    prog = <<-EPROG
application foo {
  db { one:
    password => 'secret'
  }
}
EPROG
    expect(dump(parse(prog))).to eq( [
"(application foo () (block",
"  (resource db",
"    (one",
"      (password => 'secret')))", "))" ].join("\n"))
  end

  it "accepts parameters" do
    s = "application foo($p1 = 'yo', $p2) { }"
    expect(dump(parse(s))).to eq("(application foo ((= p1 'yo') p2) ())")
  end
end
