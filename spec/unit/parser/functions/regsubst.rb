#! /usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe "the regsubst function" do

    before :each do
        @scope = Puppet::Parser::Scope.new()
    end

    it "should exist" do
        Puppet::Parser::Functions.function("regsubst").should == "function_regsubst"
    end

    it "should raise a ParseError if there is less than 3 arguments" do
        lambda { @scope.function_regsubst(["foo", "bar"]) }.should(
		raise_error(Puppet::ParseError))
    end

    it "should raise a ParseError if there is more than 5 arguments" do
        lambda { @scope.function_regsubst(["foo", "bar", "gazonk", "del", "x", "y"]) }.should(
		raise_error(Puppet::ParseError))
    end


    it "should raise a ParseError when given a bad flag" do
        lambda { @scope.function_regsubst(["foo", "bar", "gazonk", "X"]) }.should(
		raise_error(Puppet::ParseError))
    end

    it "should handle groups" do
	result = @scope.function_regsubst(
		[ '130.236.254.10',
		  '^([0-9]+)[.]([0-9]+)[.]([0-9]+)[.]([0-9]+)$',
		  '\4-\3-\2-\1'
		])
	result.should(eql("10-254-236-130"))
    end

    it "should handle simple regexps" do
	result = @scope.function_regsubst(
		[ "the monkey breaks banana trees",
		  "b[an]*a",
		  "coconut"
		])
	result.should(eql("the monkey breaks coconut trees"))
    end

    it "should handle case-sensitive regexps" do
	result = @scope.function_regsubst(
		[ "the monkey breaks baNAna trees",
		  "b[an]+a",
		  "coconut"
		])
	result.should(eql("the monkey breaks baNAna trees"))
    end

    it "should handle case-insensitive regexps" do
	result = @scope.function_regsubst(
		[ "the monkey breaks baNAna trees",
		  "b[an]+a",
		  "coconut",
		  "I"
		])
	result.should(eql("the monkey breaks coconut trees"))
    end

    it "should handle global substitutions" do
	result = @scope.function_regsubst(
		[ "the monkey breaks\tbanana trees",
		  "[ \t]",
		  "--",
		  "G"
		])
	result.should(eql("the--monkey--breaks--banana--trees"))
    end

    it "should handle global substitutions with groups" do
	result = @scope.function_regsubst(
		[ '130.236.254.10',
		  '([0-9]+)',
		  '<\1>',
		  'G'
		])
	result.should(eql('<130>.<236>.<254>.<10>'))
    end

end
