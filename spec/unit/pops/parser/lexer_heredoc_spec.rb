#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/pops'

require 'debugger'
# This is a special matcher to match easily lexer output
RSpec::Matchers.define :be_like do |*expected|
  match do |actual|
    expected.zip(actual).all? { |e,a| !e or a[0] == e or (e.is_a? Array and a[0] == e[0] and (a[1] == e[1] or (a[1].is_a?(Hash) and a[1][:value] == e[1]))) }
  end
  diffable
end
__ = nil

module EgrammarLexerSpec
  def self.tokens_scanned_from(s)
    lexer = Puppet::Pops::Parser::Lexer.new
    lexer.string = s
    lexer.fullscan[0..-2]
  end
end


describe "when lexing heredoc the lexer" do
  it "should find a single heredoc token without syntax" do
    string = "@(END)\naaa\nbbb\nccc\nEND\n"
    EgrammarLexerSpec.tokens_scanned_from(string).should be_like(
      [:HEREDOC,""], [:STRING, "aaa\nbbb\nccc\n"])
  end
  it "should find a single heredoc token with syntax" do
    string = "@(END:words)\naaa\nbbb\nccc\nEND\n"
    EgrammarLexerSpec.tokens_scanned_from(string).should be_like(
      [:HEREDOC,"words"], [:STRING, "aaa\nbbb\nccc\n"])
  end
  it "should lex two heredocs" do
    my_fixtures('two_heredocs.pp') do |file|
      lexer = Puppet::Pops::Parser::Lexer.new
      lexer.file = file
      tmp = lexer.fullscan
      tmp.should be_like(
        :LBRACK,
        :HEREDOC,
        [:STRING, "in first\n"],
        :COMMA,
        :HEREDOC,
        [:STRING, "in second\n"],
        :RBRACK
        )
      end
  end
  it "should lex two heredocs with trim" do
    my_fixtures('two_heredocs_with_trim.pp') do |file|
      lexer = Puppet::Pops::Parser::Lexer.new
      lexer.file = file
      lexer.fullscan.should be_like(
        :LBRACK,
        :HEREDOC,
        [:STRING, " in first\n"],
        :COMMA,
        :HEREDOC,
        [:STRING, "in second\n"],
        :RBRACK
        )
      end
  end
  it "should lex two heredocs with tab trim" do
    my_fixtures('two_heredocs_with_tab_trim.pp') do |file|
      lexer = Puppet::Pops::Parser::Lexer.new
      lexer.file = file
      lexer.fullscan.should be_like(
        :LBRACK,
        :HEREDOC,
        [:STRING, " in first\n"],
        :COMMA,
        :HEREDOC,
        [:STRING, "in second\n"],
        :RBRACK
        )
      end
  end
  it "should lex two heredocs with '-' trim last" do
    my_fixtures('two_heredocs_trim_last.pp') do |file|
      lexer = Puppet::Pops::Parser::Lexer.new
      lexer.file = file
      lexer.fullscan.should be_like(
        :LBRACK,
        :HEREDOC,
        [:STRING, " in first"],
        :COMMA,
        :HEREDOC,
        [:STRING, "in second"],
        :RBRACK
        )
      end
  end
  it "should lex two heredocs escapes" do
    my_fixtures('heredoc_with_escapes.pp') do |file|
      lexer = Puppet::Pops::Parser::Lexer.new
      lexer.file = file
      lexer.fullscan.should be_like(
        :LBRACK,
        [:HEREDOC, "foo"],
        [:STRING, "escape\\ tab\t return\r newline\n space .same line."],
        :COMMA,
        [:HEREDOC, ""],
        [:STRING, "escape\\ tab\t return\\r newline\\n space\\s.\\\nsame line."],
        :COMMA,
        [:HEREDOC, ""],
        [:STRING, "\\f\\i\\r\\s\\t\\\nsecond"],
        :RBRACK
        )
      end
  end
  it "should lex one heredocs in dqstring style" do
    my_fixtures('heredoc_with_dqtext.pp') do |file|
      lexer = Puppet::Pops::Parser::Lexer.new
      lexer.file = file
      lexer.fullscan.should be_like(
        :LBRACK,
        :HEREDOC,
        [:DQPRE, "Text \"and\" expr "],
        [:VARIABLE, {:line=>2, :pos=>21, :offset=>31, :length => 1, :value =>"1"}],
        :PLUS,
        [:NAME, "1"],
        [:DQMID, "\nSecond \\\"line\\\" "],
        [:VARIABLE, {:line=>3, :pos=>21, :offset=>56, :length => 1, :value =>"2"}],
        :PLUS,
        [:NAME, "2"],
        [:DQPOST, " post"],
        :RBRACK
        )
      end
  end
end
