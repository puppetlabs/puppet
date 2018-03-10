require 'spec_helper'
require 'puppet/pops'
require_relative 'parser_rspec_helper'

describe 'egrammar parsing function definitions' do
  include ParserRspecHelper

  context 'without return type' do
    it 'function foo() { 1 }' do
      expect(dump(parse('function foo() { 1 }'))).to eq("(function foo (block\n  1\n))")
    end
  end

  context 'with return type' do
    it 'function foo() >> Integer { 1 }' do
      expect(dump(parse('function foo() >> Integer { 1 }'))).to eq("(function foo (return_type Integer) (block\n  1\n))")
    end
  end
end
