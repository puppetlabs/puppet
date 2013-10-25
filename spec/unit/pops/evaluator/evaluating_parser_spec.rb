#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/pops'
require 'puppet/pops/evaluator/evaluator_impl'
require 'puppet_spec/pops'
require 'puppet_spec/scope'


# relative to this spec file (./) does not work as this file is loaded by rspec
#require File.join(File.dirname(__FILE__), '/evaluator_rspec_helper')

describe 'Puppet::Pops::Evaluator::EvaluatorImpl' do
  include PuppetSpec::Pops
  include PuppetSpec::Scope

  let(:parser) { Puppet::Pops::Parser::EvaluatingParser::Transitional.new }
  let(:node) { 'node.example.com' }
  let(:scope) { s = create_test_scope_for_node(node); s }

  context "When the evaluator performs arithmetic" do
    context "on Integers" do
      {  "2+2" => 4,
         "2 + 2" => 4,
         "7 - 3" => 4,
         "6 * 3" => 18,
         "6 / 3" => 2,
         "6 % 3" => 0,
         "10 % 3" =>  1,
         "-(6/3)" => -2,
         "-6/3  " => -2,
         "8 >> 1" => 4,
         "8 << 1" => 16,
      }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

    context "on Floats" do
      {
        "2.2 + 2.2" => 4.4,
        "7.7 - 3.3" => 4.4,
        "6.1 * 3.1" => 18.91,
        "6.6 / 3.3" => 2.0,
        "6.6 % 3.3" => 0.0,
        "10.0 % 3.0" =>  1.0,
        "-(6.0/3.0)" => -2.0,
        "-6.0/3.0 " => -2.0,
      }.each do |source, result|
        it "should parse and evaluate the expression '#{source}' to #{result}" do
          parser.evaluate_string(scope, source, __FILE__).should == result
        end
      end

      {
        "3.14 << 2" => :error,
        "3.14 >> 2" => :error,
      }.each do |source, result|
        it "should parse and raise error for '#{source}'" do
          expect { parser.evaluate_string(scope, source, __FILE__) }.to raise_error(Puppet::ParseError)
        end
      end

    end
#      it "3.14 << 2  == error"  do; expect { evaluate(literal(3.14) << literal(2))}.to raise_error(Puppet::ParseError); end
#      it "3.14 >> 2  == error"  do; expect { evaluate(literal(3.14) >> literal(2))}.to raise_error(Puppet::ParseError); end
    end
  end
end
#    context "on strings requiring boxing to Numeric" do
#      it "'2' + '2'        ==  4" do
#        evaluate(literal('2') + literal('2')).should == 4
#      end
#
#      it "'2.2' + '2.2'    ==  4.4" do
#        evaluate(literal('2.2') + literal('2.2')).should == 4.4
#      end
#
#      it "'0xF7' + '0x8'   ==  0xFF" do
#        evaluate(literal('0xF7') + literal('0x8')).should == 0xFF
#      end
#
#      it "'0367' + '010'   ==  0xFF" do
#        evaluate(literal('0367') + literal('010')).should == 0xFF
#      end
#
#      it "'0888' + '010'   ==  error" do
#        expect { evaluate(literal('0888') + literal('010'))}.to raise_error(Puppet::ParseError)
#      end
#
#      it "'0xWTF' + '010'  ==  error" do
#        expect { evaluate(literal('0xWTF') + literal('010'))}.to raise_error(Puppet::ParseError)
#      end
#
#      it "'0x12.3' + '010' ==  error" do
#        expect { evaluate(literal('0x12.3') + literal('010'))}.to raise_error(Puppet::ParseError)
#      end
#
#      it "'012.3' + '0.3'  ==  12.6 (not error, floats can start with 0)" do
#        evaluate(literal('012.3') + literal('010')) == 12.6
#      end
#    end
#  end
