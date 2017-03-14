#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require 'puppet/pops/evaluator/evaluator_impl'


# This file contains basic testing of variable references and assignments
# using a top scope and a local scope.
# It does not test variables and named scopes.
#

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/evaluator_rspec_helper')

describe 'Puppet::Pops::Impl::EvaluatorImpl' do
  include EvaluatorRspecHelper

  context "When the evaluator deals with variables" do
    context "it should handle" do
      it "simple assignment and dereference" do
        expect(evaluate_l(block( var('a').set(literal(2)+literal(2)), var('a')))).to eq(4)
      end

      it "local scope shadows top scope" do
        top_scope_block   = block( var('a').set(literal(2)+literal(2)), var('a'))
        local_scope_block = block( var('a').set(var('a') + literal(2)), var('a'))
        expect(evaluate_l(top_scope_block, local_scope_block)).to eq(6)
      end

      it "shadowed in local does not affect parent scope" do
        top_scope_block   = block( var('a').set(literal(2)+literal(2)), var('a'))
        local_scope_block = block( var('a').set(var('a') + literal(2)), var('a'))
        top_scope_again = var('a')
        expect(evaluate_l(top_scope_block, local_scope_block, top_scope_again)).to eq(4)
      end

      it "access to global names works in top scope" do
        top_scope_block   = block( var('a').set(literal(2)+literal(2)), var('::a'))
        expect(evaluate_l(top_scope_block)).to eq(4)
      end

      it "access to global names works in local scope" do
        top_scope_block     = block( var('a').set(literal(2)+literal(2)))
        local_scope_block   = block( var('a').set(literal(100)), var('b').set(var('::a')+literal(2)), var('b'))
        expect(evaluate_l(top_scope_block, local_scope_block)).to eq(6)
      end

      it "can not change a variable value in same scope" do
        expect { evaluate_l(block(var('a').set(literal(10)), var('a').set(literal(20)))) }.to raise_error(/Cannot reassign variable '\$a'/)
      end

      context "access to numeric variables" do
        it "without a match" do
          expect(evaluate_l(block(literal(2) + literal(2),
            [var(0), var(1), var(2), var(3)]))).to eq([nil, nil, nil, nil])
        end

        it "after a match" do
          expect(evaluate_l(block(literal('abc') =~ literal(/(a)(b)(c)/),
            [var(0), var(1), var(2), var(3)]))).to eq(['abc', 'a', 'b', 'c'])
        end

        it "after a failed match" do
          expect(evaluate_l(block(literal('abc') =~ literal(/(x)(y)(z)/),
            [var(0), var(1), var(2), var(3)]))).to eq([nil, nil, nil, nil])
        end

        it "a failed match does not alter previous match" do
          expect(evaluate_l(block(
            literal('abc') =~ literal(/(a)(b)(c)/),
            literal('abc') =~ literal(/(x)(y)(z)/),
            [var(0), var(1), var(2), var(3)]))).to eq(['abc', 'a', 'b', 'c'])
        end

        it "a new match completely shadows previous match" do
          expect(evaluate_l(block(
            literal('abc') =~ literal(/(a)(b)(c)/),
            literal('abc') =~ literal(/(a)bc/),
            [var(0), var(1), var(2), var(3)]))).to eq(['abc', 'a', nil, nil])
        end

        it "after a match with variable referencing a non existing group" do
          expect(evaluate_l(block(literal('abc') =~ literal(/(a)(b)(c)/),
            [var(0), var(1), var(2), var(3), var(4)]))).to eq(['abc', 'a', 'b', 'c', nil])
        end
      end
    end
  end
end
