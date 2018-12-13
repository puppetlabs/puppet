require 'spec_helper'
require 'puppet/pops'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/parser_rspec_helper')

describe "egrammar parsing heredoc" do
  include ParserRspecHelper

  it "parses plain heredoc" do
    expect(dump(parse("@(END)\nThis is\nheredoc text\nEND\n"))).to eq([
      "(@()",
      "  'This is\nheredoc text\n'",
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
      "  'This is\nheredoc text\n'",
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
      "  'This is\nheredoc text'",
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
      "  'Tex\tt\\n'",
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
      "  (cat 'Hello ' (str $name))",
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
      "  (cat 'Hello \\' (str $name))",
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
      "  (cat 'Hello \\' (str $name))",
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
      "  'First Line Second Line'",
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
      "  ' First Line  Second Line'",
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
      "  (cat 'Hello ' (str $name) '$%a')",
      ")"
    ].join("\n"))
  end

  it "parses interpolated [] expression by looking at the correct preceding char for space when there is no heredoc margin" do
    # NOTE: Important not to use the left margin feature here
    src = <<-CODE
$xxxxxxx = @("END")
${facts['os']['family']}
XXXXXXX XXX
END
CODE
    expect(dump(parse(src))).to eq([
      "(= $xxxxxxx (@()",
      "  (cat (str (slice (slice $facts 'os') 'family')) '",
      "XXXXXXX XXX",
      "')",
      "))"].join("\n"))
  end

  it "parses interpolated [] expression by looking at the correct preceding char for space when there is a heredoc margin" do
    # NOTE: Important not to use the left margin feature here - the problem in PUP 9303 is triggered by lines and text before
    # an interpolation containing []. 
    src = <<-CODE
# comment
# comment
$xxxxxxx = @("END")
    1
    2
    3
    4
    5
    YYYYY${facts['fqdn']}
    XXXXXXX XXX
    | END
CODE
    expect(dump(parse(src))).to eq([
      "(= $xxxxxxx (@()",
      "  (cat '1", "2", "3", "4", "5",
      "YYYYY' (str (slice $facts 'fqdn')) '",
      "XXXXXXX XXX",
      "')",
      "))"].join("\n"))
  end

  it "correctly reports an error location in a nested heredoc with margin" do
    # NOTE: Important not to use the left margin feature here - the problem in PUP 9303 is triggered by lines and text before
    # an interpolation containing []. 
    src = <<-CODE
# comment
# comment
$xxxxxxx = @("END")
  1
  2
  3
  4
  5
  YYYYY${facts]}
  XXXXXXX XXX
  | END
CODE
    expect{parse(src)}.to raise_error(/Syntax error at '\]' \(line: 9, column: 15\)/)
  end

  it "correctly reports an error location in a heredoc with line endings escaped" do
    # DO NOT CHANGE INDENTATION OF THIS HEREDOC
    src = <<-CODE
    # line one
    # line two
    @("END"/L)
    First Line\\
    Second Line ${facts]}
    |- END
    CODE
    expect{parse(src)}.to raise_error(/Syntax error at '\]' \(line: 5, column: 24\)/)
  end

  it "correctly reports an error location in a heredoc with line endings escaped when there is text in the margin" do
    # DO NOT CHANGE INDENTATION OR SPACING OF THIS HEREDOC
    src = <<-CODE
    # line one
    # line two
    @("END"/L)
    First Line\\
    Second Line
  x Third Line ${facts]}
    |- END
    # line 8
    # line 9
    CODE
    expect{parse(src)}.to raise_error(/Syntax error at '\]' \(line: 6, column: 23\)/)
  end

  it "correctly reports an error location in a heredoc with line endings escaped when there is text in the margin" do
    # DO NOT CHANGE INDENTATION OR SPACING OF THIS HEREDOC
    src = <<-CODE
    @(END)
AAA
 BBB
  CCC
   DDD
    EEE
     FFF
    |- END
    CODE
    expect(dump(parse(src))).to eq([
      "(@()",
      "  'AAA", # no left space trimmed
      " BBB",
      "  CCC",
      "   DDD",
      "EEE", # left space trimmed
      " FFF'", # indented one because it is one in from margin marker
      ")"].join("\n"))
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
      '    \'    hello\'',
      '  ) (@()',
      '    \'    world\'',
      '  ))))',
      '  (invoke notice \'!\')',
      ')'
    ].join("\n"))
  end

end
