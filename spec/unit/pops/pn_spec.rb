#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require 'puppet/pops/pn'

module Puppet::Pops::PN

describe 'Puppet::Pops::PN' do
  context 'Literal' do
    context 'containing the value' do
      it 'true produces the text "true"' do
        expect(Literal.new(true).to_s).to eql('true')
      end

      it 'false produces the text "false"' do
        expect(Literal.new(false).to_s).to eql('false')
      end

      it 'nil produces the text "nil"' do
        expect(Literal.new(nil).to_s).to eql('nil')
      end

      it '34 produces the text "34"' do
        expect(Literal.new(34).to_s).to eql('34')
      end

      it '3.0 produces the text "3.0"' do
        expect(Literal.new(3.0).to_s).to eql('3.0')
      end
    end

    context 'produces a double quoted text from a string such that' do
      it '"plain" produces "plain"' do
        expect(Literal.new('plain').to_s).to eql('"plain"')
      end

      it '"\t" produces a text containing a tab character' do
        expect(Literal.new("\t").to_s).to eql('"\t"')
      end

      it '"\r" produces a text containing a return character' do
        expect(Literal.new("\r").to_s).to eql('"\r"')
      end

      it '"\n" produces a text containing a newline character' do
        expect(Literal.new("\n").to_s).to eql('"\n"')
      end

      it '"\"" produces a text containing a double quote' do
        expect(Literal.new("\"").to_s).to eql('"\""')
      end

      it '"\\" produces a text containing a backslash' do
        expect(Literal.new("\\").to_s).to eql('"\\\\"')
      end

      it '"\u{14}" produces "\o024"' do
        expect(Literal.new("\u{14}").to_s).to eql('"\o024"')
      end
    end
  end

  context 'List' do
    it 'produces a text where its elements are enclosed in brackets' do
      expect(List.new([Literal.new(3), Literal.new('a'), Literal.new(true)]).to_s).to eql('[3 "a" true]')
    end

    it 'produces a text where the elements of nested lists are enclosed in brackets' do
      expect(List.new([Literal.new(3), Literal.new('a'), List.new([Literal.new(true), Literal.new(false)])]).to_s).to eql('[3 "a" [true false]]')
    end
  end

  context 'Map' do
    it 'raises error when illegal keys are used' do
      expect { Map.new([Entry.new('123', Literal.new(3))]) }.to raise_error(ArgumentError, /key 123 does not conform to pattern/)
    end

    it 'produces a text where entries are enclosed in curly braces' do
      expect(Map.new([Entry.new('a', Literal.new(3))]).to_s).to eql('{:a 3}')
    end

    it 'produces a text where the entries of nested maps are enclosed in curly braces' do
      expect(Map.new([
        Map.new([Entry.new('a', Literal.new(3))]).with_name('o')]).to_s).to eql('{:o {:a 3}}')
    end
  end

  context 'Call' do
    it 'produces a text where elements are enclosed in parenthesis' do
      expect(Call.new('+', Literal.new(3), Literal.new(5)).to_s).to eql('(+ 3 5)')
    end

    it 'produces a text where the elements of nested calls are enclosed in parenthesis' do
      expect(Map.new([
        Call.new('+', Literal.new(3), Literal.new(5)).with_name('o')]).to_s).to eql('{:o (+ 3 5)}')
    end
  end
end
end
