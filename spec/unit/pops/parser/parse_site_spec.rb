require 'spec_helper'
require 'puppet/pops'
require_relative 'parser_rspec_helper'

describe "egrammar parsing of site expression" do
  include ParserRspecHelper

  context "when parsing 'site'" do
    it "raises a syntax error" do
      expect {
        parse("site { }")
      }.to raise_error(Puppet::ParseErrorWithIssue, /Syntax error at 'site' \(line: 1, column: 1\)/)
    end
  end

  context 'When parsing collections containing application management specific keywords' do
    %w(application site produces consumes).each do |keyword|
      it "disallows the keyword '#{keyword}' in a list" do
        expect {
          parse("$a = [#{keyword}]")
        }.to raise_error(Puppet::ParseErrorWithIssue, /Syntax error at '#{keyword}' \(line: 1, column: 7\)/)
      end

      it "disallows the keyword '#{keyword}' as a key in a hash" do
        expect {
          parse("$a = {#{keyword}=>'x'}")
        }.to raise_error(Puppet::ParseErrorWithIssue, /Syntax error at '#{keyword}' \(line: 1, column: 7\)/)
      end

      it "disallows the keyword '#{keyword}' as a value in a hash" do
        expect {
          parse("$a = {'x'=>#{keyword}}")
        }.to raise_error(Puppet::ParseErrorWithIssue, /Syntax error at '#{keyword}' \(line: 1, column: 12\)/)
      end

      it "disallows the keyword '#{keyword}' as an attribute name" do
        expect {
          parse("foo { 'x': #{keyword} => 'value' } ")
        }.to raise_error(Puppet::ParseErrorWithIssue, /Syntax error at '#{keyword}' \(line: 1, column: 12\)/)
      end
    end
  end
end
