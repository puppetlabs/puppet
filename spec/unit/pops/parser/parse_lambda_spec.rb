require 'spec_helper'
require 'puppet/pops'
require_relative 'parser_rspec_helper'

describe 'egrammar parsing lambda definitions' do
  include ParserRspecHelper

  context 'without return type' do
    it 'f() |$x| { 1 }' do
      expect(dump(parse('f() |$x| { 1 }'))).to eq("(invoke f (lambda (parameters x) (block\n  1\n)))")
    end
  end

  context 'with return type' do
    it 'f() |$x| >> Integer { 1 }' do
      expect(dump(parse('f() |$x| >> Integer { 1 }'))).to eq("(invoke f (lambda (parameters x) (return_type Integer) (block\n  1\n)))")
    end
  end
end
