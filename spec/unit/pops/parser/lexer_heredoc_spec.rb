#! /usr/bin/env ruby
require 'spec_helper'
require 'matchers/match_tokens'
require 'puppet/pops'

describe "when lexing heredoc the lexer" do

  def tokens_scanned_from(s)
    lexer = Puppet::Pops::Parser::Lexer.new
    lexer.string = s
    lexer.fullscan[0..-2]
  end

  # Returns all tokens from a lexer scan from the given fixture file
  def tokens_from_fixture(file_name)
    result = nil
    my_fixtures(file_name) do |file|
      lexer = Puppet::Pops::Parser::Lexer.new
      lexer.file = file
      result = lexer.fullscan
    end
    result
  end

  it "should find a single heredoc token without syntax" do
    string = "@(END)\naaa\nbbb\nccc\nEND\n"
    tokens_scanned_from(string).should match_tokens(
      [:HEREDOC,""],
      [:STRING, "aaa\nbbb\nccc\n"])
  end

  it "should find a single heredoc token with syntax" do
    string = "@(END:words)\naaa\nbbb\nccc\nEND\n"
    tokens_scanned_from(string).should match_tokens(
      [:HEREDOC,"words"],
      [:STRING, "aaa\nbbb\nccc\n"])
  end

  it "should lex two heredocs" do
    tokens_from_fixture('two_heredocs.pp').should match_tokens(
      :LBRACK,
      :HEREDOC,
      [:STRING, "in first\n"],
      :COMMA,
      :HEREDOC,
      [:STRING, "in second\n"],
      :RBRACK
      )
  end

  it "should lex two heredocs with trim" do
    tokens_from_fixture('two_heredocs_with_trim.pp').should match_tokens(
      :LBRACK,
      :HEREDOC,
      [:STRING, " in first\n"],
      :COMMA,
      :HEREDOC,
      [:STRING, "in second\n"],
      :RBRACK
      )
  end

  it "should lex two heredocs with tab trim" do
    tokens_from_fixture('two_heredocs_with_tab_trim.pp').should match_tokens(
      :LBRACK,
      :HEREDOC,
      [:STRING, " in first\n"],
      :COMMA,
      :HEREDOC,
      [:STRING, "in second\n"],
      :RBRACK
      )
  end

  it "should lex two heredocs with '-' trim last" do
    tokens_from_fixture('two_heredocs_trim_last.pp').should match_tokens(
      :LBRACK,
      :HEREDOC,
      [:STRING, " in first"],
      :COMMA,
      :HEREDOC,
      [:STRING, "in second"],
      :RBRACK
      )
  end

  it "should lex two heredocs escapes" do
    tokens_from_fixture('heredoc_with_escapes.pp').should match_tokens(
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

  it "should lex one heredocs in dqstring style" do
    tokens_from_fixture('heredoc_with_dqtext.pp').should match_tokens(
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
