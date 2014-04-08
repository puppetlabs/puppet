require 'spec_helper'
require 'puppet/pops'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/parser_rspec_helper')

describe "egrammar parsing heredoc" do
  include ParserRspecHelper

  it "parses plain heredoc" do
    dump(parse("@(END)\nThis is\nheredoc text\nEND\n")).should == [
      "(@()",
      "  (sublocated 'This is\nheredoc text\n')",
      ")"
    ].join("\n")
  end

  it "parses heredoc with margin" do
    src = [
    "@(END)",
    "   This is",
    "   heredoc text",
    "   | END",
    ""
    ].join("\n")
    dump(parse(src)).should == [
      "(@()",
      "  (sublocated 'This is\nheredoc text\n')",
      ")"
    ].join("\n")
  end

  it "parses heredoc with margin and right newline trim" do
    src = [
    "@(END)",
    "   This is",
    "   heredoc text",
    "   |- END",
    ""
    ].join("\n")
    dump(parse(src)).should == [
      "(@()",
      "  (sublocated 'This is\nheredoc text')",
      ")"
    ].join("\n")
  end

  it "parses syntax and escape specification" do
    src = <<-CODE
    @(END:syntax/t)
    Tex\\tt\\n
    |- END
    CODE
    dump(parse(src)).should == [
      "(@(syntax)",
      "  (sublocated 'Tex\tt\\n')",
      ")"
    ].join("\n")
  end

  it "parses interpolated heredoc expression" do
    src = <<-CODE
    @("END")
    Hello $name
    |- END
    CODE
    dump(parse(src)).should == [
      "(@()",
      "  (sublocated (cat 'Hello ' (str $name) ''))",
      ")"
    ].join("\n")
  end

  it "parses interpolated heredoc expression with false start on $" do
    src = <<-CODE
    @("END")
    Hello $name$%a
    |- END
    CODE
    dump(parse(src)).should == [
      "(@()",
      "  (sublocated (cat 'Hello ' (str $name) '$%a'))",
      ")"
    ].join("\n")
  end

end
