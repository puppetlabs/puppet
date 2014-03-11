#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

describe Puppet::Pops::Model do
  it "should be possible to create an instance of a model object" do
    nop = Puppet::Pops::Model::Nop.new
    nop.class.should == Puppet::Pops::Model::Nop
  end
end

describe Puppet::Pops::Model::Factory do
  Factory = Puppet::Pops::Model::Factory
  Model = Puppet::Pops::Model

  it "construct an arithmetic expression" do
    x = Factory.literal(10) + Factory.literal(20)
    x.is_a?(Factory).should == true
    current = x.current
    current.is_a?(Model::ArithmeticExpression).should == true
    current.operator.should == :'+'
    current.left_expr.class.should == Model::LiteralInteger
    current.right_expr.class.should == Model::LiteralInteger
    current.left_expr.value.should == 10
    current.right_expr.value.should == 20
  end

  it "should be easy to compare using a model tree dumper" do
    x = Factory.literal(10) + Factory.literal(20)
    Puppet::Pops::Model::ModelTreeDumper.new.dump(x.current).should == "(+ 10 20)"
  end

  it "builder should apply precedence" do
    x = Factory.literal(2) * Factory.literal(10) + Factory.literal(20)
    Puppet::Pops::Model::ModelTreeDumper.new.dump(x.current).should == "(+ (* 2 10) 20)"
  end
end
