#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'
require 'puppet/pops/evaluator/evaluator_impl'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/evaluator_rspec_helper')

# This file contains testing of Conditionals, if, case, unless, selector
#
describe 'Puppet::Pops::Evaluator::EvaluatorImpl' do
  include EvaluatorRspecHelper

  context "When the evaluator evaluates" do
    context "an if expression" do
      it 'should output the expected result when dumped' do
        expect(dump(IF(literal(true), literal(2), literal(5)))).to eq unindent(<<-TEXT
          (if true
            (then 2)
            (else 5))
          TEXT
          )
      end

      it 'if true {5} == 5' do
        expect(evaluate(IF(literal(true), literal(5)))).to eq(5)
      end

      it 'if false {5} == nil' do
        expect(evaluate(IF(literal(false), literal(5)))).to eq(nil)
      end

      it 'if false {2} else {5} == 5' do
        expect(evaluate(IF(literal(false), literal(2), literal(5)))).to eq(5)
      end

      it 'if false {2} elsif true {5} == 5' do
        expect(evaluate(IF(literal(false), literal(2), IF(literal(true), literal(5))))).to eq(5)
      end

      it 'if false {2} elsif false {5} == nil' do
        expect(evaluate(IF(literal(false), literal(2), IF(literal(false), literal(5))))).to eq(nil)
      end
    end

    context "an unless expression" do
      it 'should output the expected result when dumped' do
        expect(dump(UNLESS(literal(true), literal(2), literal(5)))).to eq unindent(<<-TEXT
          (unless true
            (then 2)
            (else 5))
          TEXT
          )
      end

      it 'unless false {5} == 5' do
        expect(evaluate(UNLESS(literal(false), literal(5)))).to eq(5)
      end

      it 'unless true {5} == nil' do
        expect(evaluate(UNLESS(literal(true), literal(5)))).to eq(nil)
      end

      it 'unless true {2} else {5} == 5' do
        expect(evaluate(UNLESS(literal(true), literal(2), literal(5)))).to eq(5)
      end

      it 'unless true {2} elsif true {5} == 5' do
        # not supported by concrete syntax
        expect(evaluate(UNLESS(literal(true), literal(2), IF(literal(true), literal(5))))).to eq(5)
      end

      it 'unless true {2} elsif false {5} == nil' do
        # not supported by concrete syntax
        expect(evaluate(UNLESS(literal(true), literal(2), IF(literal(false), literal(5))))).to eq(nil)
      end
    end

    context "a case expression" do
      it 'should output the expected result when dumped' do
        expect(dump(CASE(literal(2),
                  WHEN(literal(1), literal('wat')),
                  WHEN([literal(2), literal(3)], literal('w00t'))
                  ))).to eq unindent(<<-TEXT
                  (case 2
                    (when (1) (then 'wat'))
                    (when (2 3) (then 'w00t')))
                  TEXT
                  )
        expect(dump(CASE(literal(2),
                  WHEN(literal(1), literal('wat')),
                  WHEN([literal(2), literal(3)], literal('w00t'))
                  ).default(literal(4)))).to eq unindent(<<-TEXT
                  (case 2
                    (when (1) (then 'wat'))
                    (when (2 3) (then 'w00t'))
                    (when (:default) (then 4)))
                  TEXT
                  )
      end

      it "case 1 { 1 : { 'w00t'} } == 'w00t'" do
        expect(evaluate(CASE(literal(1), WHEN(literal(1), literal('w00t'))))).to eq('w00t')
      end

      it "case 2 { 1,2,3 : { 'w00t'} } == 'w00t'" do
        expect(evaluate(CASE(literal(2), WHEN([literal(1), literal(2), literal(3)], literal('w00t'))))).to eq('w00t')
      end

      it "case 2 { 1,3 : {'wat'} 2: { 'w00t'} } == 'w00t'" do
        expect(evaluate(CASE(literal(2),
          WHEN([literal(1), literal(3)], literal('wat')),
          WHEN(literal(2), literal('w00t'))))).to eq('w00t')
      end

      it "case 2 { 1,3 : {'wat'} 5: { 'wat'} default: {'w00t'}} == 'w00t'" do
        expect(evaluate(CASE(literal(2),
          WHEN([literal(1), literal(3)], literal('wat')),
          WHEN(literal(5), literal('wat'))).default(literal('w00t'))
          )).to eq('w00t')
      end

      it "case 2 { 1,3 : {'wat'} 5: { 'wat'} } == nil" do
        expect(evaluate(CASE(literal(2),
          WHEN([literal(1), literal(3)], literal('wat')),
          WHEN(literal(5), literal('wat')))
          )).to eq(nil)
      end

      it "case 'banana' { 1,3 : {'wat'} /.*ana.*/: { 'w00t'} } == w00t" do
        expect(evaluate(CASE(literal('banana'),
          WHEN([literal(1), literal(3)], literal('wat')),
          WHEN(literal(/.*ana.*/), literal('w00t')))
          )).to eq('w00t')
      end

      context "with regular expressions" do
        it "should set numeric variables from the match" do
          expect(evaluate(CASE(literal('banana'),
            WHEN([literal(1), literal(3)], literal('wat')),
            WHEN(literal(/.*(ana).*/), var(1)))
            )).to eq('ana')
        end
      end
    end

    context "select expressions" do
      it 'should output the expected result when dumped' do
        expect(dump(literal(2).select(
                  MAP(literal(1), literal('wat')),
                  MAP(literal(2), literal('w00t'))
                  ))).to eq("(? 2 (1 => 'wat') (2 => 'w00t'))")
      end

      it "1 ? {1 => 'w00t'} == 'w00t'" do
        expect(evaluate(literal(1).select(MAP(literal(1), literal('w00t'))))).to eq('w00t')
      end

      it "2 ? {1 => 'wat', 2 => 'w00t'} == 'w00t'" do
        expect(evaluate(literal(2).select(
          MAP(literal(1), literal('wat')),
          MAP(literal(2), literal('w00t'))
          ))).to eq('w00t')
      end

      it "3 ? {1 => 'wat', 2 => 'wat', default => 'w00t'} == 'w00t'" do
        expect(evaluate(literal(3).select(
          MAP(literal(1), literal('wat')),
          MAP(literal(2), literal('wat')),
          MAP(literal(:default), literal('w00t'))
          ))).to eq('w00t')
      end

      it "3 ? {1 => 'wat', default => 'w00t', 3 => 'wat'} == 'w00t'" do
        expect(evaluate(literal(3).select(
          MAP(literal(1), literal('wat')),
          MAP(literal(:default), literal('w00t')),
          MAP(literal(2), literal('wat'))
          ))).to eq('w00t')
      end

      it "should set numerical variables from match" do
        expect(evaluate(literal('banana').select(
          MAP(literal(1), literal('wat')),
          MAP(literal(/.*(ana).*/), var(1))
          ))).to eq('ana')
      end
    end
  end
end
