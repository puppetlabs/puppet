require 'spec_helper'
require 'puppet/pops'
require_relative 'parser_rspec_helper'

describe "egrammar parsing of capability mappings" do
  include ParserRspecHelper

  context "when parsing 'produces'" do
    it "raises syntax error" do
      expect {
        parse("Foo produces Sql { name => value }")
      }.to raise_error(Puppet::ParseErrorWithIssue, /Syntax error at 'produces' \(line: 1, column: 5\)/)
    end
  end

  context "when parsing 'consumes'" do
    it "raises syntax error" do
      expect {
        parse("Foo consumes Sql { name => value }")
      }.to raise_error(Puppet::ParseErrorWithIssue, /Syntax error at 'consumes' \(line: 1, column: 5\)/)
    end
  end
end
