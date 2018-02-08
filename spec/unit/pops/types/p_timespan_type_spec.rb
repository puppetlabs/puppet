require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

module Puppet::Pops
module Types
describe 'Timespan type' do
  it 'is normalized in a Variant' do
    t = TypeFactory.variant(TypeFactory.timespan('10:00:00', '15:00:00'), TypeFactory.timespan('14:00:00', '17:00:00')).normalize
    expect(t).to be_a(PTimespanType)
    expect(t).to eql(TypeFactory.timespan('10:00:00', '17:00:00'))
  end

  context 'when used in Puppet expressions' do
    include PuppetSpec::Compiler
    it 'is equal to itself only' do
      code = <<-CODE
          $t = Timespan
          notice(Timespan =~ Type[Timespan])
          notice(Timespan == Timespan)
          notice(Timespan < Timespan)
          notice(Timespan > Timespan)
      CODE
      expect(eval_and_collect_notices(code)).to eq(%w(true true false false))
    end

    it 'does not consider an Integer to be an instance' do
      code = <<-CODE
        notice(assert_type(Timespan, 1234))
      CODE
      expect { eval_and_collect_notices(code) }.to raise_error(/expects a Timespan value, got Integer/)
    end

    it 'does not consider a Float to be an instance' do
      code = <<-CODE
        notice(assert_type(Timespan, 1.234))
      CODE
      expect { eval_and_collect_notices(code) }.to raise_error(/expects a Timespan value, got Float/)
    end

    context "when parameterized" do
      it 'is equal other types with the same parameterization' do
        code = <<-CODE
            notice(Timespan['01:00:00', '13:00:00'] == Timespan['01:00:00', '13:00:00'])
            notice(Timespan['01:00:00', '13:00:00'] != Timespan['01:12:20', '13:00:00'])
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true true))
      end

      it 'using just one parameter is the same as using default for the second parameter' do
        code = <<-CODE
            notice(Timespan['01:00:00'] == Timespan['01:00:00', default])
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true))
      end

      it 'if the second parameter is default, it is unlimited' do
        code = <<-CODE
            notice(Timespan('12345-23:59:59') =~ Timespan['01:00:00', default])
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true))
      end

      it 'orders parameterized types based on range inclusion' do
        code = <<-CODE
            notice(Timespan['01:00:00', '13:00:00'] < Timespan['00:00:00', '14:00:00'])
            notice(Timespan['01:00:00', '13:00:00'] > Timespan['00:00:00', '14:00:00'])
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true false))
      end
    end

    context 'a Timespan instance' do
      it 'can be created from a string' do
        code = <<-CODE
            $o = Timespan('3-11:00')
            notice($o)
            notice(type($o))
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(3-11:00:00.0 Timespan['3-11:00:00.0']))
      end

      it 'can be created from a string and format' do
        code = <<-CODE
            $o = Timespan('1d11h23m', '%Dd%Hh%Mm')
            notice($o)
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(1-11:23:00.0))
      end

      it 'can be created from a hash with string and format' do
        code = <<-CODE
            $o = Timespan({string => '1d11h23m', format => '%Dd%Hh%Mm'})
            notice($o)
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(1-11:23:00.0))
      end

      it 'can be created from a string and array of formats' do
        code = <<-CODE
            $fmts = ['%Dd%Hh%Mm%Ss', '%Hh%Mm%Ss', '%Dd%Hh%Mm', '%Dd%Hh', '%Hh%Mm', '%Mm%Ss', '%Dd', '%Hh', '%Mm', '%Ss' ]
            notice(Timespan('1d11h23m13s', $fmts))
            notice(Timespan('11h23m13s', $fmts))
            notice(Timespan('1d11h23m', $fmts))
            notice(Timespan('1d11h', $fmts))
            notice(Timespan('11h23m', $fmts))
            notice(Timespan('23m13s', $fmts))
            notice(Timespan('1d', $fmts))
            notice(Timespan('11h', $fmts))
            notice(Timespan('23m', $fmts))
            notice(Timespan('13s', $fmts))
        CODE
        expect(eval_and_collect_notices(code)).to eq(
          %w(1-11:23:13.0 0-11:23:13.0 1-11:23:00.0 1-11:00:00.0 0-11:23:00.0 0-00:23:13.0 1-00:00:00.0 0-11:00:00.0 0-00:23:00.0 0-00:00:13.0))
      end

      it 'it cannot be created using an empty formats array' do
        code = <<-CODE
            notice(Timespan('1d11h23m13s', []))
        CODE
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /parameter 'format' variant 1 expects size to be at least 1, got 0/)
      end

      it 'can be created from a integer that represents seconds' do
        code = <<-CODE
            $o = Timespan(6800)
            notice(Integer($o) == 6800)
            notice($o == Timespan('01:53:20'))
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true true))
      end

      it 'can be created from a float that represents seconds with fraction' do
        code = <<-CODE
            $o = Timespan(6800.123456789)
            notice(Float($o) == 6800.123456789)
            notice($o == Timespan('01:53:20.123456789', '%H:%M:%S.%N'))
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true true))
      end

      it 'matches the appropriate parameterized type' do
        code = <<-CODE
            $o = Timespan('3-11:12:13')
            notice(assert_type(Timespan['3-00:00:00', '4-00:00:00'], $o))
        CODE
        expect(eval_and_collect_notices(code)).to eq(['3-11:12:13.0'])
      end

      it 'does not match an inappropriate parameterized type' do
        code = <<-CODE
            $o = Timespan('1-03:04:05')
            notice(assert_type(Timespan['2-00:00:00', '3-00:00:00'], $o) |$e, $a| { 'nope' })
        CODE
        expect(eval_and_collect_notices(code)).to eq(['nope'])
      end

      it 'can be compared to other instances' do
        code = <<-CODE
            $o1 = Timespan('00:00:01')
            $o2 = Timespan('00:00:02')
            $o3 = Timespan('00:00:02')
            notice($o1 > $o3)
            notice($o1 >= $o3)
            notice($o1 < $o3)
            notice($o1 <= $o3)
            notice($o1 == $o3)
            notice($o1 != $o3)
            notice($o2 > $o3)
            notice($o2 < $o3)
            notice($o2 >= $o3)
            notice($o2 <= $o3)
            notice($o2 == $o3)
            notice($o2 != $o3)
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(false false true true false true false false true true true false))
      end

      it 'can be compared to integer that represents seconds' do
        code = <<-CODE
            $o1 = Timespan('00:00:01')
            $o2 = Timespan('00:00:02')
            $o3 = 2
            notice($o1 > $o3)
            notice($o1 >= $o3)
            notice($o1 < $o3)
            notice($o1 <= $o3)
            notice($o2 > $o3)
            notice($o2 < $o3)
            notice($o2 >= $o3)
            notice($o2 <= $o3)
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(false false true true false false true true))
      end

      it 'integer that represents seconds can be compared to it' do
        code = <<-CODE
            $o1 = 1
            $o2 = 2
            $o3 = Timespan('00:00:02')
            notice($o1 > $o3)
            notice($o1 >= $o3)
            notice($o1 < $o3)
            notice($o1 <= $o3)
            notice($o2 > $o3)
            notice($o2 < $o3)
            notice($o2 >= $o3)
            notice($o2 <= $o3)
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(false false true true false false true true))
      end

      it 'is equal to integer that represents seconds' do
        code = <<-CODE
            $o1 = Timespan('02', '%S')
            $o2 = 2
            notice($o1 == $o2)
            notice($o1 != $o2)
            notice(Integer($o1) == $o2)
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true false true))
      end

      it 'integer that represents seconds is equal to it' do
        code = <<-CODE
            $o1 = 2
            $o2 = Timespan('02', '%S')
            notice($o1 == $o2)
            notice($o1 != $o2)
            notice($o1 == Integer($o2))
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true false true))
      end

      it 'can be compared to float that represents seconds with fraction' do
        code = <<-CODE
            $o1 = Timespan('01.123456789', '%S.%N')
            $o2 = Timespan('02.123456789', '%S.%N')
            $o3 = 2.123456789
            notice($o1 > $o3)
            notice($o1 >= $o3)
            notice($o1 < $o3)
            notice($o1 <= $o3)
            notice($o2 > $o3)
            notice($o2 < $o3)
            notice($o2 >= $o3)
            notice($o2 <= $o3)
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(false false true true false false true true))
      end

      it 'float that represents seconds with fraction can be compared to it' do
        code = <<-CODE
            $o1 = 1.123456789
            $o2 = 2.123456789
            $o3 = Timespan('02.123456789', '%S.%N')
            notice($o1 > $o3)
            notice($o1 >= $o3)
            notice($o1 < $o3)
            notice($o1 <= $o3)
            notice($o2 > $o3)
            notice($o2 < $o3)
            notice($o2 >= $o3)
            notice($o2 <= $o3)
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(false false true true false false true true))
      end

      it 'is equal to float that represents seconds with fraction' do
        code = <<-CODE
            $o1 = Timespan('02.123456789', '%S.%N')
            $o2 = 2.123456789
            notice($o1 == $o2)
            notice($o1 != $o2)
            notice(Float($o1) == $o2)
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true false true))
      end

      it 'float that represents seconds with fraction is equal to it' do
        code = <<-CODE
            $o1 = 2.123456789
            $o2 = Timespan('02.123456789', '%S.%N')
            notice($o1 == $o2)
            notice($o1 != $o2)
            notice($o1 == Float($o2))
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true false true))
      end

      it 'it cannot be compared to a Timestamp' do
        code = <<-CODE
            notice(Timespan(3) < Timestamp())
        CODE
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /Timespans are only comparable to Timespans, Integers, and Floats/)
      end
    end
  end
end
end
end
