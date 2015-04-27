require 'spec_helper'
require 'puppet/pops'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/parser_rspec_helper')

describe "egrammar parsing heredoc" do
  include ParserRspecHelper

  it "parses plain heredoc" do
    expect(dump(parse("@(END)\nThis is\nheredoc text\nEND\n"))).to eq([
      "(@()",
      "  (sublocated 'This is\nheredoc text\n')",
      ")"
    ].join("\n"))
  end

  it "parses heredoc with margin" do
    src = [
    "@(END)",
    "   This is",
    "   heredoc text",
    "   | END",
    ""
    ].join("\n")
    expect(dump(parse(src))).to eq([
      "(@()",
      "  (sublocated 'This is\nheredoc text\n')",
      ")"
    ].join("\n"))
  end

  it "parses heredoc with margin and right newline trim" do
    src = [
    "@(END)",
    "   This is",
    "   heredoc text",
    "   |- END",
    ""
    ].join("\n")
    expect(dump(parse(src))).to eq([
      "(@()",
      "  (sublocated 'This is\nheredoc text')",
      ")"
    ].join("\n"))
  end

  it "parses syntax and escape specification" do
    src = <<-CODE
    @(END:syntax/t)
    Tex\\tt\\n
    |- END
    CODE
    expect(dump(parse(src))).to eq([
      "(@(syntax)",
      "  (sublocated 'Tex\tt\\n')",
      ")"
    ].join("\n"))
  end

  it "parses interpolated heredoc expression" do
    src = <<-CODE
    @("END")
    Hello $name
    |- END
    CODE
    expect(dump(parse(src))).to eq([
      "(@()",
      "  (sublocated (cat 'Hello ' (str $name) ''))",
      ")"
    ].join("\n"))
  end

  it "parses interpolated heredoc expression containing escapes" do
    src = <<-CODE
    @("END")
    Hello \\$name
    |- END
    CODE
    expect(dump(parse(src))).to eq([
      "(@()",
      "  (sublocated (cat 'Hello \\' (str $name) ''))",
      ")"
    ].join("\n"))
  end

  it "parses interpolated heredoc expression containing escapes when escaping other things than $" do
    src = <<-CODE
    @("END"/t)
    Hello \\$name
    |- END
    CODE
    expect(dump(parse(src))).to eq([
      "(@()",
      "  (sublocated (cat 'Hello \\' (str $name) ''))",
      ")"
    ].join("\n"))
  end

  it "parses with escaped newlines without preceding whitespace" do
    src = <<-CODE
    @(END/L)
    First Line\\
     Second Line
    |- END
    CODE
    parse(src)
    expect(dump(parse(src))).to eq([
      "(@()",
      "  (sublocated 'First Line Second Line')",
      ")"
    ].join("\n"))
  end

  it "parses with escaped newlines with proper margin" do
    src = <<-CODE
    @(END/L)
     First Line\\
      Second Line
    |- END
    CODE
    parse(src)
    expect(dump(parse(src))).to eq([
      "(@()",
      "  (sublocated ' First Line  Second Line')",
      ")"
    ].join("\n"))
  end

  it "parses interpolated heredoc expression with false start on $" do
    src = <<-CODE
    @("END")
    Hello $name$%a
    |- END
    CODE
    expect(dump(parse(src))).to eq([
      "(@()",
      "  (sublocated (cat 'Hello ' (str $name) '$%a'))",
      ")"
    ].join("\n"))
  end

  it 'parses multiple heredocs on the same line' do
    src = <<-CODE
    notice({ @(foo) => @(bar) })
    hello
    -foo
    world
    -bar
    notice '!'
    CODE
    expect(dump(parse(src))).to eq([
      '(block',
      '  (invoke notice ({} ((@()',
      '    (sublocated \'    hello\')',
      '  ) (@()',
      '    (sublocated \'    world\')',
      '  ))))',
      '  (invoke notice \'!\')',
      ')'
    ].join("\n"))
  end

end
