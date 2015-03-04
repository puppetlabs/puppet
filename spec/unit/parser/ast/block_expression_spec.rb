#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/parser/ast/block_expression'

describe 'Puppet::Parser::AST::BlockExpression' do
  class StackDepthAST < Puppet::Parser::AST
    attr_reader :call_depth
    def evaluate(*options)
      @call_depth = caller.length
    end
  end

  NO_SCOPE = nil

  def depth_probe
    StackDepthAST.new({})
  end

  def sequence_probe(name, sequence)
    probe = mock("Sequence Probe #{name}")
    probe.expects(:safeevaluate).in_sequence(sequence)
    probe
  end

  def block_of(children)
    Puppet::Parser::AST::BlockExpression.new(:children => children)
  end

  def assert_all_at_same_depth(*probes)
    depth0 = probes[0].call_depth
    probes.drop(1).each do |p|
      expect(p.call_depth).to eq(depth0)
    end
  end

  it "evaluates all its children at the same stack depth" do
    depth_probes = [depth_probe, depth_probe]
    expr = block_of(depth_probes)

    expr.evaluate(NO_SCOPE)

    assert_all_at_same_depth(*depth_probes)
  end

  it "evaluates sequenced children at the same stack depth" do
    depth1 = depth_probe
    depth2 = depth_probe
    depth3 = depth_probe

    expr1 = block_of([depth1])
    expr2 = block_of([depth2])
    expr3 = block_of([depth3])

    expr1.sequence_with(expr2).sequence_with(expr3).evaluate(NO_SCOPE)

    assert_all_at_same_depth(depth1, depth2, depth3)
  end

  it "evaluates sequenced children in order" do
    evaluation_order = sequence("Child evaluation order")
    expr1 = block_of([sequence_probe("Step 1", evaluation_order)])
    expr2 = block_of([sequence_probe("Step 2", evaluation_order)])
    expr3 = block_of([sequence_probe("Step 3", evaluation_order)])

    expr1.sequence_with(expr2).sequence_with(expr3).evaluate(NO_SCOPE)
  end
end

