#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

module Puppet::Pops::PN

describe 'Puppet::Pops::PN' do
  context 'Literal' do
    context 'prodces a string with' do
      it 'boolean' do
        expect(Literal.new(true).to_s).to eql('true')
      end

      it 'nil' do
        expect(Literal.new(nil).to_s).to eql('nil')
      end

      it 'integer' do
        expect(Literal.new(34).to_s).to eql('34')
      end

      it 'float' do
        expect(Literal.new(3.0).to_s).to eql('3.0')
      end

      it 'string' do
        expect(Literal.new('plain').to_s).to eql('"plain"')
      end

      context 'string contaiing escaped' do
        it 'tab' do
          expect(Literal.new("\t").to_s).to eql('"\t"')
        end

        it 'return' do
          expect(Literal.new("\r").to_s).to eql('"\r"')
        end

        it 'newline' do
          expect(Literal.new("\n").to_s).to eql('"\n"')
        end

        it 'double quote' do
          expect(Literal.new("\"").to_s).to eql('"\""')
        end

        it 'backslash' do
          expect(Literal.new("\\").to_s).to eql('"\\\\"')
        end

        it 'control' do
          expect(Literal.new("\u{14}").to_s).to eql('"\o024"')
        end
      end
    end
  end

  context 'List' do
    it 'produces string' do
      expect(List.new([Literal.new(3), Literal.new('a'), Literal.new(true)]).to_s).to eql('[3 "a" true]')
    end

    it 'can be nested' do
      expect(List.new([Literal.new(3), Literal.new('a'), List.new([Literal.new(true), Literal.new(false)])]).to_s).to eql('[3 "a" [true false]]')
    end
  end

  context 'Map' do
    it 'raises error when illegal keys are used' do
      expect { Map.new([Entry.new('123', Literal.new(3))]) }.to raise_error(ArgumentError, /key 123 does not conform to pattern/)
    end

    it 'produces string' do
      expect(Map.new([Entry.new('a', Literal.new(3))]).to_s).to eql('{:a 3}')
    end

    it 'can be nested' do
      expect(Map.new([
        Map.new([Entry.new('a', Literal.new(3))]).with_name('o')]).to_s).to eql('{:o {:a 3}}')
    end
  end

  context 'Call' do
    it 'produces string' do
      expect(Call.new('+', Literal.new(3), Literal.new(5)).to_s).to eql('(+ 3 5)')
    end

    it 'can be nested' do
      expect(Map.new([
        Call.new('+', Literal.new(3), Literal.new(5)).with_name('o')]).to_s).to eql('{:o (+ 3 5)}')
    end
  end
end
end
