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
      evaluate(literal(1)).should == 1
      evaluate(literal(3.14)).should == 3.14
    end

    it 'should evaluate strings to string' do
      evaluate(literal('banana')).should == 'banana'
    end

    it 'should evaluate booleans to booleans' do
      evaluate(literal(false)).should == false
      evaluate(literal(true)).should == true
    end

    it 'should evaluate names to strings' do
      evaluate(fqn('banana')).should == 'banana'
    end

    it 'should evaluator types to types' do
      array_type = Puppet::Pops::Types::PArrayType.new()
      array_type.element_type = Puppet::Pops::Types::PDataType.new()
      evaluate(fqr('Array')).should == array_type
    end
  end

  context "When the evaluator evaluates Lists" do
    it "should create an Array when evaluating a LiteralList" do
      evaluate(literal([1,2,3])).should == [1,2,3]
    end

    it "[...[...[]]] should create nested arrays without trouble" do
      evaluate(literal([1,[2.0, 2.1, [2.2]],[3.0, 3.1]])).should == [1,[2.0, 2.1, [2.2]],[3.0, 3.1]]
    end

    it "[2 + 2] should evaluate expressions in entries" do
      x = literal([literal(2) + literal(2)]);
      Puppet::Pops::Model::ModelTreeDumper.new.dump(x).should == "([] (+ 2 2))"
      evaluate(x)[0].should == 4
    end

    it "[1,2,3] == [1,2,3] == true" do
      evaluate(literal([1,2,3]) == literal([1,2,3])).should == true;
    end

    it "[1,2,3] != [2,3,4] == true" do
      evaluate(literal([1,2,3]).ne(literal([2,3,4]))).should == true;
    end

    it "[1, 2, 3][2] == 3" do
      evaluate(literal([1,2,3])[2]).should == 3
    end
  end

  context "When the evaluator evaluates Hashes" do
    it "should create a  Hash when evaluating a LiteralHash" do
      evaluate(literal({'a'=>1,'b'=>2})).should == {'a'=>1,'b'=>2}
    end

    it "{...{...{}}} should create nested hashes without trouble" do
      evaluate(literal({'a'=>1,'b'=>{'x'=>2.1,'y'=>2.2}})).should == {'a'=>1,'b'=>{'x'=>2.1,'y'=>2.2}}
    end

    it "{'a'=> 2 + 2} should evaluate values in entries" do
      evaluate(literal({'a'=> literal(2) + literal(2)}))['a'].should == 4
    end

    it "{'a'=> 1, 'b'=>2} == {'a'=> 1, 'b'=>2} == true" do
      evaluate(literal({'a'=> 1, 'b'=>2}) == literal({'a'=> 1, 'b'=>2})).should == true;
    end

    it "{'a'=> 1, 'b'=>2} != {'x'=> 1, 'y'=>3} == true" do
      evaluate(literal({'a'=> 1, 'b'=>2}).ne(literal({'x'=> 1, 'y'=>3}))).should == true;
    end

    it "{'a' => 1, 'b' => 2}['b'] == 2" do
      evaluate(literal({:a => 1, :b => 2})[:b]).should == 2
    end
  end

  context 'When the evaluator evaluates a Block' do
    it 'an empty block evaluates to nil' do
      evaluate(block()).should == nil
    end

    it 'a block evaluates to its last expression' do
      evaluate(block(literal(1), literal(2))).should == 2
    end
  end
end
