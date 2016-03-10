#! /usr/bin/env ruby
require 'spec_helper'

describe "the shellquote function" do
  let :node     do Puppet::Node.new('localhost') end
  let :compiler do Puppet::Parser::Compiler.new(node) end
  let :scope    do Puppet::Parser::Scope.new(compiler) end

  it "should exist" do
    expect(Puppet::Parser::Functions.function("shellquote")).to eq("function_shellquote")
  end

  it "should handle no arguments" do
    expect(scope.function_shellquote([])).to eq("")
  end

  it "should handle several simple arguments" do
    expect(scope.function_shellquote(
      ['foo', 'bar@example.com', 'localhost:/dev/null', 'xyzzy+-4711,23']
    )).to eq('foo bar@example.com localhost:/dev/null xyzzy+-4711,23')
  end

  it "should handle array arguments" do
    expect(scope.function_shellquote(
      ['foo', ['bar@example.com', 'localhost:/dev/null'],
      'xyzzy+-4711,23']
    )).to eq('foo bar@example.com localhost:/dev/null xyzzy+-4711,23')
  end

  it "should quote unsafe characters" do
    expect(scope.function_shellquote(['/etc/passwd ', '(ls)', '*', '[?]', "'&'"])).
      to eq('"/etc/passwd " "(ls)" "*" "[?]" "\'&\'"')
  end

  it "should deal with double quotes" do
    expect(scope.function_shellquote(['"foo"bar"'])).to eq('\'"foo"bar"\'')
  end

  it "should cope with dollar signs" do
    expect(scope.function_shellquote(['$PATH', 'foo$bar', '"x$"'])).
      to eq("'$PATH' 'foo$bar' '\"x$\"'")
  end

  it "should deal with apostrophes (single quotes)" do
    expect(scope.function_shellquote(["'foo'bar'", "`$'EDITOR'`"])).
      to eq('"\'foo\'bar\'" "\\`\\$\'EDITOR\'\\`"')
  end

  it "should cope with grave accents (backquotes)" do
    expect(scope.function_shellquote(['`echo *`', '`ls "$MAILPATH"`'])).
      to eq("'`echo *`' '`ls \"$MAILPATH\"`'")
  end

  it "should deal with both single and double quotes" do
    expect(scope.function_shellquote(['\'foo"bar"xyzzy\'', '"foo\'bar\'xyzzy"'])).
      to eq('"\'foo\\"bar\\"xyzzy\'" "\\"foo\'bar\'xyzzy\\""')
  end

  it "should handle multiple quotes *and* dollars and backquotes" do
    expect(scope.function_shellquote(['\'foo"$x`bar`"xyzzy\''])).
      to eq('"\'foo\\"\\$x\\`bar\\`\\"xyzzy\'"')
  end

  it "should handle linefeeds" do
    expect(scope.function_shellquote(["foo \n bar"])).to eq("\"foo \n bar\"")
  end
end
