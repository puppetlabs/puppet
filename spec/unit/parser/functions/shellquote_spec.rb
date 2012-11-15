#! /usr/bin/env ruby
require 'spec_helper'

describe "the shellquote function" do
  let :node     do Puppet::Node.new('localhost') end
  let :compiler do Puppet::Parser::Compiler.new(node) end
  let :scope    do Puppet::Parser::Scope.new(compiler) end

  it "should exist" do
    Puppet::Parser::Functions.function("shellquote").should == "function_shellquote"
  end

  it "should handle no arguments" do
    scope.function_shellquote([]).should == ""
  end

  it "should handle several simple arguments" do
    scope.function_shellquote(
      ['foo', 'bar@example.com', 'localhost:/dev/null', 'xyzzy+-4711,23']
    ).should == 'foo bar@example.com localhost:/dev/null xyzzy+-4711,23'
  end

  it "should handle array arguments" do
    scope.function_shellquote(
      ['foo', ['bar@example.com', 'localhost:/dev/null'],
      'xyzzy+-4711,23']
    ).should == 'foo bar@example.com localhost:/dev/null xyzzy+-4711,23'
  end

  it "should quote unsafe characters" do
    scope.function_shellquote(['/etc/passwd ', '(ls)', '*', '[?]', "'&'"]).
      should == '"/etc/passwd " "(ls)" "*" "[?]" "\'&\'"'
  end

  it "should deal with double quotes" do
    scope.function_shellquote(['"foo"bar"']).should == '\'"foo"bar"\''
  end

  it "should cope with dollar signs" do
    scope.function_shellquote(['$PATH', 'foo$bar', '"x$"']).
      should == "'$PATH' 'foo$bar' '\"x$\"'"
  end

  it "should deal with apostrophes (single quotes)" do
    scope.function_shellquote(["'foo'bar'", "`$'EDITOR'`"]).
      should == '"\'foo\'bar\'" "\\`\\$\'EDITOR\'\\`"'
  end

  it "should cope with grave accents (backquotes)" do
    scope.function_shellquote(['`echo *`', '`ls "$MAILPATH"`']).
      should == "'`echo *`' '`ls \"$MAILPATH\"`'"
  end

  it "should deal with both single and double quotes" do
    scope.function_shellquote(['\'foo"bar"xyzzy\'', '"foo\'bar\'xyzzy"']).
      should == '"\'foo\\"bar\\"xyzzy\'" "\\"foo\'bar\'xyzzy\\""'
  end

  it "should handle multiple quotes *and* dollars and backquotes" do
    scope.function_shellquote(['\'foo"$x`bar`"xyzzy\'']).
      should == '"\'foo\\"\\$x\\`bar\\`\\"xyzzy\'"'
  end

  it "should handle linefeeds" do
    scope.function_shellquote(["foo \n bar"]).should == "\"foo \n bar\""
  end
end
