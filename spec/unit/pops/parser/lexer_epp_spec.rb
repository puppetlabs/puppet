#! /usr/bin/env ruby
require 'spec_helper'
require 'matchers/match_tokens'
require 'puppet/pops'

module EgrammarLexerEppSpec
  def self.tokens_scanned_from(s)
    lexer = Puppet::Pops::Parser::Lexer.new({:mode => :epp})
    lexer.string = s
    lexer.fullscan[0..-2]
  end
end


describe "when lexing epp the lexer" do
  it "finds a single render string" do
    string = "Hello template world"
    EgrammarLexerEppSpec.tokens_scanned_from(string).should match_tokens(
      :EPP_START,
      [:RENDER_STRING, "Hello template world"]
      )
  end

  it "skips comments" do
    string = "Hello <%# shy %>template world"
    EgrammarLexerEppSpec.tokens_scanned_from(string).should match_tokens(
      :EPP_START,
      [:RENDER_STRING, "Hello template world"]
      )
  end

  it "finds a render expression" do
    string = "Hello <%= $x %> world"
    EgrammarLexerEppSpec.tokens_scanned_from(string).should match_tokens(
      :EPP_START,
      [:RENDER_STRING, "Hello "],
      :RENDER_EXPR,
      [:VARIABLE, "x"],
      [:RENDER_STRING, " world"]
      )
  end

  it "finds an expression" do
    string = "Hello <% $x = 1 %> world"
    EgrammarLexerEppSpec.tokens_scanned_from(string).should match_tokens(
      :EPP_START,
      [:RENDER_STRING, "Hello "],
      [:VARIABLE, "x"],
      :EQUALS,
      [:NAME, "1"],
      [:RENDER_STRING, " world"]
      )
  end

  it "performs left trim" do
    string = "Hello <%- $x = 1 %> world"
    EgrammarLexerEppSpec.tokens_scanned_from(string).should match_tokens(
      :EPP_START,
      [:RENDER_STRING, "Hello"],
      [:VARIABLE, "x"],
      :EQUALS,
      [:NAME, "1"],
      [:RENDER_STRING, " world"]
      )
  end

  it "performs right trim" do
    string = "Hello <% $x = 1 -%> world"
    EgrammarLexerEppSpec.tokens_scanned_from(string).should match_tokens(
      :EPP_START,
      [:RENDER_STRING, "Hello "],
      [:VARIABLE, "x"],
      :EQUALS,
      [:NAME, "1"],
      [:RENDER_STRING, "world"]
      )
  end

  it "does not skip initial space" do
    string = " <% $x = 1 %> world"
    EgrammarLexerEppSpec.tokens_scanned_from(string).should match_tokens(
      :EPP_START,
      [:RENDER_STRING, " "],
      [:VARIABLE, "x"],
      :EQUALS,
      [:NAME, "1"],
      [:RENDER_STRING, " world"]
      )
  end

  it "right-trims comments" do
    string = "Hello <%# shy -%> template world"
    EgrammarLexerEppSpec.tokens_scanned_from(string).should match_tokens(
      :EPP_START,
      [:RENDER_STRING, "Hello template world"]
      )
  end

  it "processes escaped epp tags" do
    string = "Hello <%% escaped %%> template world"
    EgrammarLexerEppSpec.tokens_scanned_from(string).should match_tokens(
      :EPP_START,
      [:RENDER_STRING, "Hello <% escaped %> template world"]
      )
  end
end
