#!/usr/bin/env rspec
require 'spec_helper'

describe "the shellquote function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  it "should exist" do
    Puppet::Parser::Functions.function("shellquote").should == "function_shellquote"
  end


  it "should handle no arguments" do
    result = @scope.function_shellquote([])
    result.should(eql(""))
  end

  it "should handle several simple arguments" do
    result = @scope.function_shellquote( ['foo', 'bar@example.com', 'localhost:/dev/null', 'xyzzy+-4711,23'])
    result.should(eql( 'foo bar@example.com localhost:/dev/null xyzzy+-4711,23'))
  end

  it "should handle array arguments" do

    result = @scope.function_shellquote(

      ['foo', ['bar@example.com', 'localhost:/dev/null'],

      'xyzzy+-4711,23'])
    result.should(eql(
      'foo bar@example.com localhost:/dev/null xyzzy+-4711,23'))
  end

  it "should quote unsafe characters" do
    result = @scope.function_shellquote( ['/etc/passwd ', '(ls)', '*', '[?]', "'&'"])
    result.should(eql( '"/etc/passwd " "(ls)" "*" "[?]" "\'&\'"'))
  end

  it "should deal with double quotes" do
    result = @scope.function_shellquote(
      ['"foo"bar"'])
    result.should(eql(
      '\'"foo"bar"\''))
  end

  it "should cope with dollar signs" do
    result = @scope.function_shellquote( ['$PATH', 'foo$bar', '"x$"'])
    result.should(eql( "'$PATH' 'foo$bar' '\"x$\"'"))
  end

  it "should deal with apostrophes (single quotes)" do
    result = @scope.function_shellquote(
      ["'foo'bar'", "`$'EDITOR'`"])
    result.should(eql(
      '"\'foo\'bar\'" "\\`\\$\'EDITOR\'\\`"'))
  end

  it "should cope with grave accents (backquotes)" do
    result = @scope.function_shellquote( ['`echo *`', '`ls "$MAILPATH"`'])
    result.should(eql( "'`echo *`' '`ls \"$MAILPATH\"`'"))
  end

  it "should deal with both single and double quotes" do
    result = @scope.function_shellquote( ['\'foo"bar"xyzzy\'', '"foo\'bar\'xyzzy"'])
    result.should(eql( '"\'foo\\"bar\\"xyzzy\'" "\\"foo\'bar\'xyzzy\\""'))
  end

  it "should handle multiple quotes *and* dollars and backquotes" do
    result = @scope.function_shellquote( ['\'foo"$x`bar`"xyzzy\''])
    result.should(eql( '"\'foo\\"\\$x\\`bar\\`\\"xyzzy\'"'))
  end

  it "should handle linefeeds" do
    result = @scope.function_shellquote( ["foo \n bar"])
    result.should(eql( "\"foo \n bar\""))
  end

end
