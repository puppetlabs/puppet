#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'

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

    # 64 bit signed integer max and min
    MAX_INTEGER =  0x7fffffffffffffff
    MIN_INTEGER = -0x8000000000000000

    context "on integer values that cause 64 bit overflow" do
      it "MAX + 1 => error" do
        expect{
          evaluate(literal(MAX_INTEGER) + literal(1))
        }.to raise_error(/resulted in a value outside of Puppet Integer max range/)
      end

      it "MAX - -1 => error" do
        expect{
          evaluate(literal(MAX_INTEGER) - literal(-1))
        }.to raise_error(/resulted in a value outside of Puppet Integer max range/)
      end

      it "MAX * 2 => error" do
        expect{
          evaluate(literal(MAX_INTEGER) * literal(2))
        }.to raise_error(/resulted in a value outside of Puppet Integer max range/)
      end

      it "(MAX+1)*2 / 2 => error" do
        expect{
          evaluate(literal((MAX_INTEGER+1)*2) / literal(2))
        }.to raise_error(/resulted in a value outside of Puppet Integer max range/)
      end

      it "MAX << 1 => error" do
        expect{
          evaluate(literal(MAX_INTEGER) << literal(1))
        }.to raise_error(/resulted in a value outside of Puppet Integer max range/)
      end

      it "((MAX+1)*2)  << 1 => error" do
        expect{
          evaluate(literal((MAX_INTEGER+1)*2) >> literal(1))
        }.to raise_error(/resulted in a value outside of Puppet Integer max range/)
      end

      it "MIN - 1 => error" do
        expect{
          evaluate(literal(MIN_INTEGER) - literal(1))
        }.to raise_error(/resulted in a value outside of Puppet Integer min range/)
      end

      it "does not error on the border values" do
          expect(evaluate(literal(MAX_INTEGER) + literal(MIN_INTEGER))).to eq(MAX_INTEGER+MIN_INTEGER)
      end

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

    context 'on timespans' do
      include PuppetSpec::Compiler

      it 'Timespan + Timespan = Timespan' do
        code = 'notice(assert_type(Timespan, Timespan({days => 3}) + Timespan({hours => 12})))'
        expect(eval_and_collect_notices(code)).to eql(['3-12:00:00.0'])
      end

      it 'Timespan - Timespan = Timespan' do
        code = 'notice(assert_type(Timespan, Timespan({days => 3}) - Timespan({hours => 12})))'
        expect(eval_and_collect_notices(code)).to eql(['2-12:00:00.0'])
      end

      it 'Timespan + -Timespan = Timespan' do
        code = 'notice(assert_type(Timespan, Timespan({days => 3}) + -Timespan({hours => 12})))'
        expect(eval_and_collect_notices(code)).to eql(['2-12:00:00.0'])
      end

      it 'Timespan - -Timespan = Timespan' do
        code = 'notice(assert_type(Timespan, Timespan({days => 3}) - -Timespan({hours => 12})))'
        expect(eval_and_collect_notices(code)).to eql(['3-12:00:00.0'])
      end

      it 'Timespan / Timespan = Float' do
        code = "notice(assert_type(Float, Timespan({days => 3}) / Timespan('0-12:00:00')))"
        expect(eval_and_collect_notices(code)).to eql(['6.0'])
      end

      it 'Timespan * Timespan is an error' do
        code = 'notice(Timespan({days => 3}) * Timespan({hours => 12}))'
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /A Timestamp cannot be multiplied by a Timespan/)
      end

      it 'Timespan + Numeric = Timespan (numeric treated as seconds)' do
        code = 'notice(assert_type(Timespan, Timespan({days => 3}) + 7300.0))'
        expect(eval_and_collect_notices(code)).to eql(['3-02:01:40.0'])
      end

      it 'Timespan - Numeric = Timespan (numeric treated as seconds)' do
        code = "notice(assert_type(Timespan, Timespan({days => 3}) - 7300.123))"
        expect(eval_and_collect_notices(code)).to eql(['2-21:58:19.877'])
      end

      it 'Timespan * Numeric = Timespan (numeric treated as seconds)' do
        code = "notice(strftime(assert_type(Timespan, Timespan({days => 3}) * 2), '%D'))"
        expect(eval_and_collect_notices(code)).to eql(['6'])
      end

      it 'Numeric + Timespan = Timespan (numeric treated as seconds)' do
        code = 'notice(assert_type(Timespan, 7300.0 + Timespan({days => 3})))'
        expect(eval_and_collect_notices(code)).to eql(['3-02:01:40.0'])
      end

      it 'Numeric - Timespan = Timespan (numeric treated as seconds)' do
        code = "notice(strftime(assert_type(Timespan, 300000 - Timespan({days => 3})), '%H:%M'))"
        expect(eval_and_collect_notices(code)).to eql(['11:20'])
      end

      it 'Numeric * Timespan = Timespan (numeric treated as seconds)' do
        code = "notice(strftime(assert_type(Timespan, 2 * Timespan({days => 3})), '%D'))"
        expect(eval_and_collect_notices(code)).to eql(['6'])
      end

      it 'Timespan + Timestamp = Timestamp' do
        code = "notice(assert_type(Timestamp, Timespan({days => 3}) + Timestamp('2016-08-27T16:44:49.999 UTC')))"
        expect(eval_and_collect_notices(code)).to eql(['2016-08-30T16:44:49.999000000 UTC'])
      end

      it 'Timespan - Timestamp is an error' do
        code = 'notice(Timespan({days => 3}) - Timestamp())'
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /A Timestamp cannot be subtracted from a Timespan/)
      end

      it 'Timespan * Timestamp is an error' do
        code = 'notice(Timespan({days => 3}) * Timestamp())'
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /A Timestamp cannot be multiplied by a Timestamp/)
      end

      it 'Timespan / Timestamp is an error' do
        code = 'notice(Timespan({days => 3}) / Timestamp())'
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /A Timespan cannot be divided by a Timestamp/)
      end
    end


    context 'on timestamps' do
      include PuppetSpec::Compiler

      it 'Timestamp + Timestamp is an error' do
        code = 'notice(Timestamp() + Timestamp())'
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /A Timestamp cannot be added to a Timestamp/)
      end

      it 'Timestamp + Timespan = Timestamp' do
        code = "notice(assert_type(Timestamp, Timestamp('2016-10-10') + Timespan('0-12:00:00')))"
        expect(eval_and_collect_notices(code)).to eql(['2016-10-10T12:00:00.000000000 UTC'])
      end

      it 'Timestamp + Numeric = Timestamp' do
        code = "notice(assert_type(Timestamp, Timestamp('2016-10-10T12:00:00.000') + 3600.123))"
        expect(eval_and_collect_notices(code)).to eql(['2016-10-10T13:00:00.123000000 UTC'])
      end

      it 'Numeric + Timestamp = Timestamp' do
        code = "notice(assert_type(Timestamp, 3600.123 + Timestamp('2016-10-10T12:00:00.000')))"
        expect(eval_and_collect_notices(code)).to eql(['2016-10-10T13:00:00.123000000 UTC'])
      end

      it 'Timestamp - Timestamp = Timespan' do
        code = "notice(assert_type(Timespan, Timestamp('2016-10-10') - Timestamp('2015-10-10')))"
        expect(eval_and_collect_notices(code)).to eql(['366-00:00:00.0'])
      end

      it 'Timestamp - Timespan = Timestamp' do
        code = "notice(assert_type(Timestamp, Timestamp('2016-10-10') - Timespan('0-12:00:00')))"
        expect(eval_and_collect_notices(code)).to eql(['2016-10-09T12:00:00.000000000 UTC'])
      end

      it 'Timestamp - Numeric = Timestamp' do
        code = "notice(assert_type(Timestamp, Timestamp('2016-10-10') - 3600.123))"
        expect(eval_and_collect_notices(code)).to eql(['2016-10-09T22:59:59.877000000 UTC'])
      end

      it 'Numeric - Timestamp = Timestamp' do
        code = "notice(assert_type(Timestamp, 123 - Timestamp('2016-10-10')))"
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /Operator '-' is not applicable.*when right side is a Timestamp/)
      end

      it 'Timestamp / Timestamp is an error' do
        code = "notice(Timestamp('2016-10-10') / Timestamp())"
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /Operator '\/' is not applicable to a Timestamp/)
      end

      it 'Timestamp / Timespan is an error' do
        code = "notice(Timestamp('2016-10-10') / Timespan('0-12:00:00'))"
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /Operator '\/' is not applicable to a Timestamp/)
      end

      it 'Timestamp / Numeric is an error' do
        code = "notice(Timestamp('2016-10-10') / 3600.123)"
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /Operator '\/' is not applicable to a Timestamp/)
      end

      it 'Numeric / Timestamp is an error' do
        code = "notice(3600.123 / Timestamp('2016-10-10'))"
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /Operator '\/' is not applicable.*when right side is a Timestamp/)
      end

      it 'Timestamp * Timestamp is an error' do
        code = "notice(Timestamp('2016-10-10') * Timestamp())"
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /Operator '\*' is not applicable to a Timestamp/)
      end

      it 'Timestamp * Timespan is an error' do
        code = "notice(Timestamp('2016-10-10') * Timespan('0-12:00:00'))"
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /Operator '\*' is not applicable to a Timestamp/)
      end

      it 'Timestamp * Numeric is an error' do
        code = "notice(Timestamp('2016-10-10') * 3600.123)"
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /Operator '\*' is not applicable to a Timestamp/)
      end

      it 'Numeric * Timestamp is an error' do
        code = "notice(3600.123 * Timestamp('2016-10-10'))"
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /Operator '\*' is not applicable.*when right side is a Timestamp/)
      end
    end
  end
end
