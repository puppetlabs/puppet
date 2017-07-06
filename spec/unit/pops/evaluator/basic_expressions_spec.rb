#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/pops'
require 'puppet/pops/evaluator/evaluator_impl'


# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/evaluator_rspec_helper')

describe 'Puppet::Pops::Evaluator::EvaluatorImpl' do
  include EvaluatorRspecHelper

  context "When the evaluator evaluates literals" do
    it 'should evaluator numbers to numbers' do
      expect(evaluate(literal(1))).to eq(1)
      expect(evaluate(literal(3.14))).to eq(3.14)
    end

    it 'should evaluate strings to string' do
      expect(evaluate(literal('banana'))).to eq('banana')
    end

    it 'should evaluate booleans to booleans' do
      expect(evaluate(literal(false))).to eq(false)
      expect(evaluate(literal(true))).to eq(true)
    end

    it 'should evaluate names to strings' do
      expect(evaluate(fqn('banana'))).to eq('banana')
    end

    it 'should evaluator types to types' do
      array_type = Puppet::Pops::Types::PArrayType::DATA
      expect(evaluate(fqr('Array'))).to eq(array_type)
    end
  end

  context "When the evaluator evaluates Lists" do
    it "should create an Array when evaluating a LiteralList" do
      expect(evaluate(literal([1,2,3]))).to eq([1,2,3])
    end

    it "[...[...[]]] should create nested arrays without trouble" do
      expect(evaluate(literal([1,[2.0, 2.1, [2.2]],[3.0, 3.1]]))).to eq([1,[2.0, 2.1, [2.2]],[3.0, 3.1]])
    end

    it "[2 + 2] should evaluate expressions in entries" do
      x = literal([literal(2) + literal(2)]);
      expect(Puppet::Pops::Model::ModelTreeDumper.new.dump(x)).to eq("([] (+ 2 2))")
      expect(evaluate(x)[0]).to eq(4)
    end

    it "[1,2,3] == [1,2,3] == true" do
      expect(evaluate(literal([1,2,3]) == literal([1,2,3]))).to eq(true);
    end

    it "[1,2,3] != [2,3,4] == true" do
      expect(evaluate(literal([1,2,3]).ne(literal([2,3,4])))).to eq(true);
    end

    it "[1, 2, 3][2] == 3" do
      expect(evaluate(literal([1,2,3])[2])).to eq(3)
    end
  end

  context "When the evaluator evaluates Hashes" do
    it "should create a  Hash when evaluating a LiteralHash" do
      expect(evaluate(literal({'a'=>1,'b'=>2}))).to eq({'a'=>1,'b'=>2})
    end

    it "{...{...{}}} should create nested hashes without trouble" do
      expect(evaluate(literal({'a'=>1,'b'=>{'x'=>2.1,'y'=>2.2}}))).to eq({'a'=>1,'b'=>{'x'=>2.1,'y'=>2.2}})
    end

    it "{'a'=> 2 + 2} should evaluate values in entries" do
      expect(evaluate(literal({'a'=> literal(2) + literal(2)}))['a']).to eq(4)
    end

    it "{'a'=> 1, 'b'=>2} == {'a'=> 1, 'b'=>2} == true" do
      expect(evaluate(literal({'a'=> 1, 'b'=>2}) == literal({'a'=> 1, 'b'=>2}))).to eq(true);
    end

    it "{'a'=> 1, 'b'=>2} != {'x'=> 1, 'y'=>3} == true" do
      expect(evaluate(literal({'a'=> 1, 'b'=>2}).ne(literal({'x'=> 1, 'y'=>3})))).to eq(true);
    end

    it "{'a' => 1, 'b' => 2}['b'] == 2" do
      expect(evaluate(literal({:a => 1, :b => 2})[:b])).to eq(2)
    end
  end

  context 'When the evaluator evaluates a Block' do
    it 'an empty block evaluates to nil' do
      expect(evaluate(block())).to eq(nil)
    end

    it 'a block evaluates to its last expression' do
      expect(evaluate(block(literal(1), literal(2)))).to eq(2)
    end
  end
end
