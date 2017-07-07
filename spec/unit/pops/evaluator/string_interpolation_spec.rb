#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/pops'
require 'puppet/pops/evaluator/evaluator_impl'


# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/evaluator_rspec_helper')

describe 'Puppet::Pops::Evaluator::EvaluatorImpl' do
  include EvaluatorRspecHelper

  context "When evaluator performs string interpolation" do
    it "should interpolate a bare word as a variable name, \"${var}\"" do
      a_block = block(var('a').set(literal(10)), string('value is ', text(fqn('a')), ' yo'))
      expect(evaluate(a_block)).to eq('value is 10 yo')
    end

    it "should interpolate a variable in a text expression, \"${$var}\"" do
      a_block = block(var('a').set(literal(10)), string('value is ', text(var(fqn('a'))), ' yo'))
      expect(evaluate(a_block)).to eq('value is 10 yo')
    end

    it "should interpolate a variable, \"$var\"" do
      a_block = block(var('a').set(literal(10)), string('value is ', var(fqn('a')), ' yo'))
      expect(evaluate(a_block)).to eq('value is 10 yo')
    end

    it "should interpolate any expression in a text expression, \"${$var*2}\"" do
      a_block = block(var('a').set(literal(5)), string('value is ', text(var(fqn('a')) * literal(2)) , ' yo'))
      expect(evaluate(a_block)).to eq('value is 10 yo')
    end

    it "should interpolate any expression without a text expression, \"${$var*2}\"" do
      # there is no concrete syntax for this, but the parser can generate this simpler
      # equivalent form where the expression is not wrapped in a TextExpression
      a_block = block(var('a').set(literal(5)), string('value is ', var(fqn('a')) * literal(2) , ' yo'))
      expect(evaluate(a_block)).to eq('value is 10 yo')
    end

    # TODO: Add function call tests - Pending implementation of calls in the evaluator
  end
end
