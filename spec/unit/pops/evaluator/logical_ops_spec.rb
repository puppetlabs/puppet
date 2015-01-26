#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/pops'
require 'puppet/pops/evaluator/evaluator_impl'


# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/evaluator_rspec_helper')

describe 'Puppet::Pops::Evaluator::EvaluatorImpl' do
  include EvaluatorRspecHelper

  context "When the evaluator performs boolean operations" do
    context "using operator AND" do
      it "true  && true  == true" do
        expect(evaluate(literal(true).and(literal(true)))).to eq(true)
      end

      it "false && true  == false" do
        expect(evaluate(literal(false).and(literal(true)))).to eq(false)
      end

      it "true  && false == false" do
        expect(evaluate(literal(true).and(literal(false)))).to eq(false)
      end

      it "false && false == false" do
        expect(evaluate(literal(false).and(literal(false)))).to eq(false)
      end
    end

    context "using operator OR" do
      it "true  || true  == true" do
        expect(evaluate(literal(true).or(literal(true)))).to eq(true)
      end

      it "false || true  == true" do
        expect(evaluate(literal(false).or(literal(true)))).to eq(true)
      end

      it "true  || false == true" do
        expect(evaluate(literal(true).or(literal(false)))).to eq(true)
      end

      it "false || false == false" do
        expect(evaluate(literal(false).or(literal(false)))).to eq(false)
      end
    end

    context "using operator NOT" do
      it "!false         == true" do
        expect(evaluate(literal(false).not())).to eq(true)
      end

      it "!true          == false" do
        expect(evaluate(literal(true).not())).to eq(false)
      end
    end

    context "on values requiring boxing to Boolean" do
      it "'x'            == true" do
        expect(evaluate(literal('x').not())).to eq(false)
      end

      it "''             == true" do
        expect(evaluate(literal('').not())).to eq(false)
      end

      it ":undef         == false" do
        expect(evaluate(literal(:undef).not())).to eq(true)
      end
    end

    context "connectives should stop when truth is obtained" do
      it "true && false && error  == false (and no failure)" do
        expect(evaluate(literal(false).and(literal('0xwtf') + literal(1)).and(literal(true)))).to eq(false)
      end

      it "false || true || error  == true (and no failure)" do
        expect(evaluate(literal(true).or(literal('0xwtf') + literal(1)).or(literal(false)))).to eq(true)
      end

      it "false || false || error == error (false positive test)" do
        # TODO: Change the exception type
        expect {evaluate(literal(true).and(literal('0xwtf') + literal(1)).or(literal(false)))}.to raise_error(Puppet::ParseError)
      end
    end
  end
end
