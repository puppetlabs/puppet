#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/parser_rspec_helper')

describe "egrammar parsing of capability mappings" do
  include ParserRspecHelper

  before(:all) do
    with_app_management(true)
  end

  after(:all) do
    with_app_management(false)
  end

  it "parses produces" do
    prog = <<-EOS
Foo produces Sql { name => value }
EOS
    ast = <<EOS.strip
(produces Foo Sql ((name => value)))
EOS
    expect(dump(parse(prog))).to eq(ast)
  end

  it "parses consumes" do
    prog = <<-EOS
Foo consumes Sql { name => value }
EOS
    ast = <<EOS.strip
(consumes Foo Sql ((name => value)))
EOS
    expect(dump(parse(prog))).to eq(ast)
  end

end
