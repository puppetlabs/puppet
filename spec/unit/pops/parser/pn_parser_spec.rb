#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require 'puppet/pops/pn'

module Puppet::Pops
module Parser

describe 'Puppet::Pops::Parser::PNParser' do
  context 'parses the text' do
    it '"true" to PN::Literal(true)' do
      expect(PNParser.new.parse('true')).to eql(lit(true))
    end

    it '"false" to PN::Literal(false)' do
      expect(PNParser.new.parse('false')).to eql(lit(false))
    end

    it '"nil" to PN::Literal(nil)' do
      expect(PNParser.new.parse('nil')).to eql(lit(nil))
    end

    it '"123" to PN::Literal(123)' do
      expect(PNParser.new.parse('123')).to eql(lit(123))
    end

    it '"-123" to PN::Literal(-123)' do
      expect(PNParser.new.parse('-123')).to eql(lit(-123))
    end

    it '"123.45" to PN::Literal(123.45)' do
      expect(PNParser.new.parse('123.45')).to eql(lit(123.45))
    end

    it '"-123.45" to PN::Literal(-123.45)' do
      expect(PNParser.new.parse('-123.45')).to eql(lit(-123.45))
    end

    it '"123.45e12" to PN::Literal(123.45e12)' do
      expect(PNParser.new.parse('123.45e12')).to eql(lit(123.45e12))
    end

    it '"123.45e+12" to PN::Literal(123.45e+12)' do
      expect(PNParser.new.parse('123.45e+12')).to eql(lit(123.45e+12))
    end

    it '"123.45e-12" to PN::Literal(123.45e-12)' do
      expect(PNParser.new.parse('123.45e-12')).to eql(lit(123.45e-12))
    end

    it '"hello" to PN::Literal("hello")' do
      expect(PNParser.new.parse('"hello"')).to eql(lit('hello'))
    end

    it '"\t" to PN::Literal("\t")' do
      expect(PNParser.new.parse('"\t"')).to eql(lit("\t"))
    end

    it '"\r" to PN::Literal("\r")' do
      expect(PNParser.new.parse('"\r"')).to eql(lit("\r"))
    end

    it '"\n" to PN::Literal("\n")' do
      expect(PNParser.new.parse('"\n"')).to eql(lit("\n"))
    end

    it '"\"" to PN::Literal("\"")' do
      expect(PNParser.new.parse('"\""')).to eql(lit('"'))
    end

    it '"\\\\" to PN::Literal("\\")' do
      expect(PNParser.new.parse('"\\\\"')).to eql(lit("\\"))
    end

    it '"\o024" to PN::Literal("\u{14}")' do
      expect(PNParser.new.parse('"\o024"')).to eql(lit("\u{14}"))
    end
  end

  it 'parses elements enclosed in brackets to a PN::List' do
    expect(PNParser.new.parse('[1 "2" true false nil]')).to eql(PN::List.new([lit(1), lit('2'), lit(true), lit(false), lit(nil)]))
  end

  it 'parses elements enclosed in parenthesis to a PN::Call' do
    expect(PNParser.new.parse('(+ 1 2)')).to eql(PN::Call.new('+', lit(1), lit(2)))
  end

  it 'parses entries enclosed in curly braces to a PN::Map' do
    expect(PNParser.new.parse('{:a 1 :b "2" :c true}')).to eql(PN::Map.new([entry('a', 1), entry('b', '2'), entry('c', true)]))
  end

  def entry(k, v)
    PN::Entry.new(k, lit(v))
  end

  def lit(v)
    PN::Literal.new(v)
  end
end
end
end
