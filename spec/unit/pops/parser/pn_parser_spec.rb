#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require 'puppet/pops/pn'

module Puppet::Pops
module Parser

describe 'Puppet::Pops::Parser::PNParser' do
  context 'when parsing literals' do
    it 'can parse boolean true' do
      expect(PNParser.new.parse('true')).to eql(lit(true))
    end

    it 'can parse boolean false' do
      expect(PNParser.new.parse('false')).to eql(lit(false))
    end

    it 'can parse nil' do
      expect(PNParser.new.parse('nil')).to eql(lit(nil))
    end

    it 'can parse an integer' do
      expect(PNParser.new.parse('123')).to eql(lit(123))
    end

    it 'can parse a negative integer' do
      expect(PNParser.new.parse('-123')).to eql(lit(-123))
    end

    it 'can parse a float' do
      expect(PNParser.new.parse('123.45')).to eql(lit(123.45))
    end

    it 'can parse a negative float' do
      expect(PNParser.new.parse('-123.45')).to eql(lit(-123.45))
    end

    it 'can parse float using exponent notation' do
      expect(PNParser.new.parse('123.45e12')).to eql(lit(123.45e12))
    end

    it 'can parse float using explicit positive exponent notation' do
      expect(PNParser.new.parse('123.45e+12')).to eql(lit(123.45e+12))
    end

    it 'can parse float using negative exponent notation' do
      expect(PNParser.new.parse('-123.45e-12')).to eql(lit(-123.45e-12))
    end

    it 'can parse quoted string' do
      expect(PNParser.new.parse('"hello"')).to eql(lit('hello'))
    end

    context 'can parse quoted string with escaped' do
      it 'tab' do
        expect(PNParser.new.parse('"\t"')).to eql(lit("\t"))
      end

      it 'carriage return' do
        expect(PNParser.new.parse('"\r"')).to eql(lit("\r"))
      end

      it 'newline' do
        expect(PNParser.new.parse('"\n"')).to eql(lit("\n"))
      end

      it 'double quote' do
        expect(PNParser.new.parse('"\""')).to eql(lit('"'))
      end

      it 'escape' do
        expect(PNParser.new.parse('"\\\\"')).to eql(lit("\\"))
      end

      it 'control' do
        expect(PNParser.new.parse('"\o024"')).to eql(lit("\u{14}"))
      end
    end
  end

  it 'can parse a list' do
    expect(PNParser.new.parse('[1 "2" true false nil]')).to eql(PN::List.new([lit(1), lit('2'), lit(true), lit(false), lit(nil)]))
  end

  it 'can parse a call' do
    expect(PNParser.new.parse('(+ 1 2)')).to eql(PN::Call.new('+', lit(1), lit(2)))
  end

  it 'can parse a map' do
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