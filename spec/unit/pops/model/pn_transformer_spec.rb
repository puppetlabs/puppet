#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require 'puppet/pops/pn'

module Puppet::Pops
module Model

describe 'Puppet::Pops::Model::PNTransformer' do
  def call(name, *elements)
    PN::Call.new(name, *elements.map { |e| lit(e) })
  end

  context 'transforms the expression' do
    it '"\'hello\'" into the corresponding literal' do
      x = Factory.literal('hello')
      expect(Puppet::Pops::Model::PNTransformer.transform(x.model)).to eq(lit('hello'))
    end

    it '"32" into into the corresponding literal' do
      x = Factory.literal(32)
      expect(Puppet::Pops::Model::PNTransformer.transform(x.model)).to eq(lit(32))
    end

    it '"true" into into the corresponding literal' do
      x = Factory.literal(true)
      expect(Puppet::Pops::Model::PNTransformer.transform(x.model)).to eq(lit(true))
    end

    it '"10 + 20" into (+ 10 20)' do
      x = Factory.literal(10) + Factory.literal(20)
      expect(Puppet::Pops::Model::PNTransformer.transform(x.model)).to eq(call('+', 10, 20))
    end

    it '"[10, 20]" into into (array 10 20)' do
      x = Factory.literal([10, 20])
      expect(Puppet::Pops::Model::PNTransformer.transform(x.model)).to eq(call('array', 10, 20))
    end

    it '"{a => 1, b => 2}" into into (hash (=> ("a" 1)) (=> ("b" 2)))' do
      x = Factory.HASH([Factory.KEY_ENTRY(Factory.literal('a'), Factory.literal(1)), Factory.KEY_ENTRY(Factory.literal('b'), Factory.literal(2))])
      expect(Puppet::Pops::Model::PNTransformer.transform(x.model)).to eq(
        call('hash', call('=>', 'a', 1), call('=>', 'b', 2)))
    end
  end

  def lit(value)
    value.is_a?(PN) ? value : PN::Literal.new(value)
  end
end
end
end

