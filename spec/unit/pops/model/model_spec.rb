#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

describe Puppet::Pops::Model do
  it "should be possible to create an instance of a model object" do
    nop = Puppet::Pops::Model::Nop.new
    expect(nop.class).to eq(Puppet::Pops::Model::Nop)
  end
end

describe Puppet::Pops::Model::Factory do
  Factory = Puppet::Pops::Model::Factory
  Model = Puppet::Pops::Model

  it "construct an arithmetic expression" do
    x = Factory.literal(10) + Factory.literal(20)
    expect(x.is_a?(Factory)).to eq(true)
    current = x.current
    expect(current.is_a?(Model::ArithmeticExpression)).to eq(true)
    expect(current.operator).to eq(:'+')
    expect(current.left_expr.class).to eq(Model::LiteralInteger)
    expect(current.right_expr.class).to eq(Model::LiteralInteger)
    expect(current.left_expr.value).to eq(10)
    expect(current.right_expr.value).to eq(20)
  end

  it "should be easy to compare using a model tree dumper" do
    x = Factory.literal(10) + Factory.literal(20)
    expect(Puppet::Pops::Model::ModelTreeDumper.new.dump(x.current)).to eq("(+ 10 20)")
  end

  it "builder should apply precedence" do
    x = Factory.literal(2) * Factory.literal(10) + Factory.literal(20)
    expect(Puppet::Pops::Model::ModelTreeDumper.new.dump(x.current)).to eq("(+ (* 2 10) 20)")
  end
end
