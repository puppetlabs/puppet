require 'spec_helper'
require 'puppet/pops'
require_relative 'parser_rspec_helper'

describe "egrammar parsing of 'application'" do
  include ParserRspecHelper

  it "raises a syntax error" do
    expect {
      parse("application foo { }")
    }.to raise_error(Puppet::ParseErrorWithIssue, /Syntax error at 'application' \(line: 1, column: 1\)/)
  end
end
