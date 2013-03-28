#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops/api'
require 'puppet/pops/impl'

describe Puppet::Pops::API::Model do
  it "should be possible to create an instance of a model object" do
    nop = Puppet::Pops::API::Model::Nop.new
    nop.class.should == Puppet::Pops::API::Model::Nop
  end
end

describe Puppet::Pops::Impl::Model::Factory do
  Factory = Puppet::Pops::Impl::Model::Factory
  Model = Puppet::Pops::API::Model

  it "construct an arithmetic expression" do
    x = Factory.literal(10) + Factory.literal(20)
    x.is_a?(Factory).should == true
    current = x.current
    current.is_a?(Model::ArithmeticExpression).should == true
    current.operator.should == :'+'
    current.left_expr.class.should == Model::LiteralNumber
    current.right_expr.class.should == Model::LiteralNumber
    current.left_expr.value.should == 10
    current.right_expr.value.should == 20
  end

  it "should be easy to compare using a model tree dumper" do
    x = Factory.literal(10) + Factory.literal(20)
    Puppet::Pops::Impl::Model::ModelTreeDumper.new.dump(x.current).should == "(+ 10 20)"
  end

  it "builder should apply precedence" do
    x = Factory.literal(2) * Factory.literal(10) + Factory.literal(20)
    Puppet::Pops::Impl::Model::ModelTreeDumper.new.dump(x.current).should == "(+ (* 2 10) 20)"
  end
end
