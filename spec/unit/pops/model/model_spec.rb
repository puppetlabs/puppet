#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

describe Puppet::Pops::Model do
  it "should be possible to create an instance of a model object" do
    nop = Puppet::Pops::Model::Nop.new(Puppet::Pops::Parser::Locator.locator('code', 'file'), 0, 0)
    expect(nop.class).to eq(Puppet::Pops::Model::Nop)
  end
end

describe Puppet::Pops::Model::Factory do
  Factory = Puppet::Pops::Model::Factory
  Model = Puppet::Pops::Model

  it "construct an arithmetic expression" do
    x = Factory.literal(10) + Factory.literal(20)
    expect(x.is_a?(Factory)).to eq(true)
    model = x.model
    expect(model.is_a?(Model::ArithmeticExpression)).to eq(true)
    expect(model.operator).to eq('+')
    expect(model.left_expr.class).to eq(Model::LiteralInteger)
    expect(model.right_expr.class).to eq(Model::LiteralInteger)
    expect(model.left_expr.value).to eq(10)
    expect(model.right_expr.value).to eq(20)
  end

  it "should be easy to compare using a model tree dumper" do
    x = Factory.literal(10) + Factory.literal(20)
    expect(Puppet::Pops::Model::ModelTreeDumper.new.dump(x.model)).to eq("(+ 10 20)")
  end

  it "builder should apply precedence" do
    x = Factory.literal(2) * Factory.literal(10) + Factory.literal(20)
    expect(Puppet::Pops::Model::ModelTreeDumper.new.dump(x.model)).to eq("(+ (* 2 10) 20)")
  end

describe "should be describable with labels"
  it 'describes a PlanDefinition as "Plan Definition"' do
    expect(Puppet::Pops::Model::ModelLabelProvider.new.label(Factory.PLAN('test', [], nil))).to eq("Plan Definition")
  end
end
