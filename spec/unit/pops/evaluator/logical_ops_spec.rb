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
        evaluate(literal(true).and(literal(true))).should == true
      end

      it "false && true  == false" do
        evaluate(literal(false).and(literal(true))).should == false
      end

      it "true  && false == false" do
        evaluate(literal(true).and(literal(false))).should == false
      end

      it "false && false == false" do
        evaluate(literal(false).and(literal(false))).should == false
      end
    end

    context "using operator OR" do
      it "true  || true  == true" do
        evaluate(literal(true).or(literal(true))).should == true
      end

      it "false || true  == true" do
        evaluate(literal(false).or(literal(true))).should == true
      end

      it "true  || false == true" do
        evaluate(literal(true).or(literal(false))).should == true
      end

      it "false || false == false" do
        evaluate(literal(false).or(literal(false))).should == false
      end
    end

    context "using operator NOT" do
      it "!false         == true" do
        evaluate(literal(false).not()).should == true
      end

      it "!true          == false" do
        evaluate(literal(true).not()).should == false
      end
    end

    context "on values requiring boxing to Boolean" do
      it "'x'            == true" do
        evaluate(literal('x').not()).should == false
      end

      it "''             == true" do
        evaluate(literal('').not()).should == false
      end

      it ":undef         == false" do
        evaluate(literal(:undef).not()).should == true
      end
    end

    context "connectives should stop when truth is obtained" do
      it "true && false && error  == false (and no failure)" do
        evaluate(literal(false).and(literal('0xwtf') + literal(1)).and(literal(true))).should == false
      end

      it "false || true || error  == true (and no failure)" do
        evaluate(literal(true).or(literal('0xwtf') + literal(1)).or(literal(false))).should == true
      end

      it "false || false || error == error (false positive test)" do
        # TODO: Change the exception type
        expect {evaluate(literal(true).and(literal('0xwtf') + literal(1)).or(literal(false)))}.to raise_error(Puppet::ParseError)
      end
    end
  end
end
