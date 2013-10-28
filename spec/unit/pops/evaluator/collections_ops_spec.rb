#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/pops'
require 'puppet/pops/evaluator/evaluator_impl'
require 'puppet/pops/types/type_factory'


# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/evaluator_rspec_helper')

describe 'Puppet::Pops::Evaluator::EvaluatorImpl/Concat/Delete' do
  include EvaluatorRspecHelper

  context 'The evaluator when operating on an Array' do
    it 'concatenates another array using +' do
      expect(evaluate(literal([1,2,3]) + literal([4,5]))).to eql([1,2,3,4,5])
    end

    it 'concatenates another nested array using +' do
      expect(evaluate(literal([1,2,3]) + literal([[4,5]]))).to eql([1,2,3,[4,5]])
    end

    it 'concatenates a hash by converting it to array' do
      expect(evaluate(literal([1,2,3]) + literal({'a' => 1, 'b'=>2}))).to eql([1,2,3,['a',1],['b',2]])
    end

    it 'concatenates a non array value with +' do
      expect(evaluate(literal([1,2,3]) + literal(4))).to eql([1,2,3,4])
    end

    it 'appends another array using <<' do
      expect(evaluate(literal([1,2,3]) << literal([4,5]))).to eql([1,2,3,[4,5]])
    end

    it 'appends a hash without conversion when << operator is used' do
      expect(evaluate(literal([1,2,3]) << literal({'a' => 1, 'b'=>2}))).to eql([1,2,3,{'a' => 1, 'b'=>2}])
    end

    it 'appends another non array using <<' do
      expect(evaluate(literal([1,2,3]) << literal(4))).to eql([1,2,3,4])
    end

    it 'computes the difference with another array using -' do
      expect(evaluate(literal([1,2,3,4]) - literal([2,3]))).to eql([1,4])
    end

    it 'computes the difference with a non array using -' do
      expect(evaluate(literal([1,2,3,4]) - literal(2))).to eql([1,3,4])
    end

    it 'does not recurse into nested arrays when computing diff' do
      expect(evaluate(literal([1,2,3,[2],4]) - literal(2))).to eql([1,3,[2],4])
    end

    it 'can compute diff with sub arrays' do
      expect(evaluate(literal([1,2,3,[2,3],4]) - literal([[2,3]]))).to eql([1,2,3,4])
    end

    it 'computes difference by removing all matching instances' do
      expect(evaluate(literal([1,2,3,3,2,4,2,3]) - literal([2,3]))).to eql([1,4])
    end

    it 'computes difference with a hash by converting it to an array' do
      expect(evaluate(literal([1,2,3,['a',1],['b',2]]) - literal({'a' => 1, 'b'=>2}))).to eql([1,2,3])
    end

    it 'diffs hashes when given in an array' do
      expect(evaluate(literal([1,2,3,{'a'=>1,'b'=>2}]) - literal([{'a' => 1, 'b'=>2}]))).to eql([1,2,3])
    end

    it 'raises and error when LHS of << is a hash' do
    expect {
       evaluate(literal({'a' => 1, 'b'=>2}) << literal(1))
    }.to raise_error(/Operator '<<' is not applicable to a Hash/)
    end
  end

  context 'The evaluator when operating on a Hash' do
    it 'merges with another Hash using +' do
      expect(evaluate(literal({'a' => 1, 'b'=>2}) + literal({'c' => 3}))).to eql({'a' => 1, 'b'=>2, 'c' => 3})
    end

    it 'merges RHS on top of LHS ' do
      expect(evaluate(literal({'a' => 1, 'b'=>2}) + literal({'c' => 3, 'b'=>3}))).to eql({'a' => 1, 'b'=>3, 'c' => 3})
    end

    it 'merges a flat array of pairs converted to a hash' do
      expect(evaluate(literal({'a' => 1, 'b'=>2}) + literal(['c', 3, 'b', 3]))).to eql({'a' => 1, 'b'=>3, 'c' => 3})
    end

    it 'merges an array converted to a hash' do
      expect(evaluate(literal({'a' => 1, 'b'=>2}) + literal([['c', 3], ['b', 3]]))).to eql({'a' => 1, 'b'=>3, 'c' => 3})
    end

    it 'computes difference with another hash using the - operator' do
      expect(evaluate(literal({'a' => 1, 'b'=>2}) - literal({'b' => 3}))).to eql({'a' => 1 })
    end

    it 'computes difference with an array by treating array as array of keys' do
      expect(evaluate(literal({'a' => 1, 'b'=>2,'c'=>3}) - literal(['b', 'c']))).to eql({'a' => 1 })
    end

    it 'computes difference with a non array/hash by treating it as a key' do
      expect(evaluate(literal({'a' => 1, 'b'=>2,'c'=>3}) - literal('c'))).to eql({'a' => 1, 'b' => 2 })
    end
  end

end
