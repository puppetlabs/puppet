#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require 'puppet/pops/pn'

module Puppet::Pops
module PN

describe 'Puppet::Pops::PN' do
  context 'Literal' do
    context 'containing the value' do
      it 'true produces the text "true"' do
        expect(lit(true).to_s).to eql('true')
      end

      it 'false produces the text "false"' do
        expect(lit(false).to_s).to eql('false')
      end

      it 'nil produces the text "nil"' do
        expect(lit(nil).to_s).to eql('nil')
      end

      it '34 produces the text "34"' do
        expect(lit(34).to_s).to eql('34')
      end

      it '3.0 produces the text "3.0"' do
        expect(lit(3.0).to_s).to eql('3.0')
      end
    end

    context 'produces a double quoted text from a string such that' do
      it '"plain" produces "plain"' do
        expect(lit('plain').to_s).to eql('"plain"')
      end

      it '"\t" produces a text containing a tab character' do
        expect(lit("\t").to_s).to eql('"\t"')
      end

      it '"\r" produces a text containing a return character' do
        expect(lit("\r").to_s).to eql('"\r"')
      end

      it '"\n" produces a text containing a newline character' do
        expect(lit("\n").to_s).to eql('"\n"')
      end

      it '"\"" produces a text containing a double quote' do
        expect(lit("\"").to_s).to eql('"\""')
      end

      it '"\\" produces a text containing a backslash' do
        expect(lit("\\").to_s).to eql('"\\\\"')
      end

      it '"\u{14}" produces "\o024"' do
        expect(lit("\u{14}").to_s).to eql('"\o024"')
      end
    end
  end

  context 'List' do
    it 'produces a text where its elements are enclosed in brackets' do
      expect(List.new([lit(3), lit('a'), lit(true)]).to_s).to eql('[3 "a" true]')
    end

    it 'produces a text where the elements of nested lists are enclosed in brackets' do
      expect(List.new([lit(3), lit('a'), List.new([lit(true), lit(false)])]).to_s).to eql('[3 "a" [true false]]')
    end

    context 'with indent' do
      it 'produces a text where the each element is on an indented line ' do
        s = ''
        List.new([lit(3), lit('a'), List.new([lit(true), lit(false)])]).format(Indent.new('  '), s)
        expect(s).to eql(<<-RESULT.unindent[0..-2]) # unindent and strip last newline
        [
          3
          "a"
          [
            true
            false]]
        RESULT
      end
    end
  end

  context 'Map' do
    it 'raises error when illegal keys are used' do
      expect { Map.new([Entry.new('123', lit(3))]) }.to raise_error(ArgumentError, /key 123 does not conform to pattern/)
    end

    it 'produces a text where entries are enclosed in curly braces' do
      expect(Map.new([Entry.new('a', lit(3))]).to_s).to eql('{:a 3}')
    end

    it 'produces a text where the entries of nested maps are enclosed in curly braces' do
      expect(Map.new([
        Map.new([Entry.new('a', lit(3))]).with_name('o')]).to_s).to eql('{:o {:a 3}}')
    end

    context 'with indent' do
      it 'produces a text where the each element is on an indented line ' do
        s = ''
        Map.new([
          Map.new([Entry.new('a', lit(3)), Entry.new('b', lit(5))]).with_name('o')]).format(Indent.new('  '), s)
        expect(s).to eql(<<-RESULT.unindent[0..-2]) # unindent and strip last newline
        {
          :o {
            :a 3
            :b 5}}
        RESULT
      end
    end
  end

  context 'Call' do
    it 'produces a text where elements are enclosed in parenthesis' do
      expect(Call.new('+', lit(3), lit(5)).to_s).to eql('(+ 3 5)')
    end

    it 'produces a text where the elements of nested calls are enclosed in parenthesis' do
      expect(Map.new([
        Call.new('+', lit(3), lit(5)).with_name('o')]).to_s).to eql('{:o (+ 3 5)}')
    end

    context 'with indent' do
      it 'produces a text where the each element is on an indented line ' do
        s = ''
        Call.new('+', lit(3), lit(Call.new('-', lit(10), lit(5)))).format(Indent.new('  '), s)
        expect(s).to eql(<<-RESULT.unindent[0..-2]) # unindent and strip last newline
        (+
          3
          (-
            10
            5))
        RESULT
      end
    end
  end

  def lit(v)
    v.is_a?(PN) ? v : Literal.new(v)
  end
end
end
end
