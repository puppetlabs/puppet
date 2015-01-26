#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/pops'
require 'puppet/pops/evaluator/evaluator_impl'


# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/evaluator_rspec_helper')

describe 'Puppet::Pops::Evaluator::EvaluatorImpl' do
  include EvaluatorRspecHelper

  context "When the evaluator performs arithmetic" do
    context "on Integers" do
      it "2 + 2  ==  4"   do; expect(evaluate(literal(2) + literal(2))).to eq(4) ; end
      it "7 - 3  ==  4"   do; expect(evaluate(literal(7) - literal(3))).to eq(4) ; end
      it "6 * 3  ==  18"  do; expect(evaluate(literal(6) * literal(3))).to eq(18); end
      it "6 / 3  ==  2"   do; expect(evaluate(literal(6) / literal(3))).to eq(2) ; end
      it "6 % 3  ==  0"   do; expect(evaluate(literal(6) % literal(3))).to eq(0) ; end
      it "10 % 3 ==  1"   do; expect(evaluate(literal(10) % literal(3))).to eq(1); end
      it "-(6/3) == -2"   do; expect(evaluate(minus(literal(6) / literal(3)))).to eq(-2) ; end
      it "-6/3   == -2"   do; expect(evaluate(minus(literal(6)) / literal(3))).to eq(-2) ; end
      it "8 >> 1 == 4"    do; expect(evaluate(literal(8) >> literal(1))).to eq(4) ; end
      it "8 << 1 == 16"   do; expect(evaluate(literal(8) << literal(1))).to eq(16); end
      it "8 >> -1 == 16"    do; expect(evaluate(literal(8) >> literal(-1))).to eq(16) ; end
      it "8 << -1 == 4"   do; expect(evaluate(literal(8) << literal(-1))).to eq(4); end
    end

    context "on Floats" do
      it "2.2 + 2.2  ==  4.4"   do; expect(evaluate(literal(2.2) + literal(2.2))).to eq(4.4)  ; end
      it "7.7 - 3.3  ==  4.4"   do; expect(evaluate(literal(7.7) - literal(3.3))).to eq(4.4)  ; end
      it "6.1 * 3.1  ==  18.91" do; expect(evaluate(literal(6.1) * literal(3.1))).to eq(18.91); end
      it "6.6 / 3.3  ==  2.0"   do; expect(evaluate(literal(6.6) / literal(3.3))).to eq(2.0)  ; end
      it "-(6.0/3.0) == -2.0"   do; expect(evaluate(minus(literal(6.0) / literal(3.0)))).to eq(-2.0); end
      it "-6.0/3.0   == -2.0"   do; expect(evaluate(minus(literal(6.0)) / literal(3.0))).to eq(-2.0); end
      it "6.6 % 3.3  ==  0.0"   do; expect { evaluate(literal(6.6) % literal(3.3))}.to raise_error(Puppet::ParseError); end
        it "10.0 % 3.0 ==  1.0"   do; expect { evaluate(literal(10.0) % literal(3.0))}.to raise_error(Puppet::ParseError); end
      it "3.14 << 2  == error"  do; expect { evaluate(literal(3.14) << literal(2))}.to raise_error(Puppet::ParseError); end
      it "3.14 >> 2  == error"  do; expect { evaluate(literal(3.14) >> literal(2))}.to raise_error(Puppet::ParseError); end
    end

    context "on strings requiring boxing to Numeric" do
      it "'2' + '2'        ==  4" do
        expect(evaluate(literal('2') + literal('2'))).to eq(4)
      end

      it "'2.2' + '2.2'    ==  4.4" do
        expect(evaluate(literal('2.2') + literal('2.2'))).to eq(4.4)
      end

      it "'0xF7' + '0x8'   ==  0xFF" do
        expect(evaluate(literal('0xF7') + literal('0x8'))).to eq(0xFF)
      end

      it "'0367' + '010'   ==  0xFF" do
        expect(evaluate(literal('0367') + literal('010'))).to eq(0xFF)
      end

      it "'0888' + '010'   ==  error" do
        expect { evaluate(literal('0888') + literal('010'))}.to raise_error(Puppet::ParseError)
      end

      it "'0xWTF' + '010'  ==  error" do
        expect { evaluate(literal('0xWTF') + literal('010'))}.to raise_error(Puppet::ParseError)
      end

      it "'0x12.3' + '010' ==  error" do
        expect { evaluate(literal('0x12.3') + literal('010'))}.to raise_error(Puppet::ParseError)
      end

      it "'012.3' + '010'  ==  20.3 (not error, floats can start with 0)" do
        expect(evaluate(literal('012.3') + literal('010'))).to eq(20.3)
      end
    end
  end
end
