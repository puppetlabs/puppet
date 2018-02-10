require 'spec_helper'
require 'puppet/pops'
require 'puppet_spec/compiler'

module Puppet::Pops
module Types
describe 'Timestamp type' do

  it 'is normalized in a Variant' do
    t = TypeFactory.variant(TypeFactory.timestamp('2015-03-01', '2016-01-01'), TypeFactory.timestamp('2015-11-03', '2016-12-24')).normalize
    expect(t).to be_a(PTimestampType)
    expect(t).to eql(TypeFactory.timestamp('2015-03-01', '2016-12-24'))
  end

  it 'DateTime#_strptime creates hash with :leftover field' do
    expect(DateTime._strptime('2015-05-04 and bogus', '%F')).to include(:leftover)
    expect(DateTime._strptime('2015-05-04T10:34:11.003 UTC and bogus', '%FT%T.%N %Z')).to include(:leftover)
  end

  context 'when used in Puppet expressions' do
    include PuppetSpec::Compiler
    it 'is equal to itself only' do
      code = <<-CODE
          $t = Timestamp
          notice(Timestamp =~ Type[Timestamp])
          notice(Timestamp == Timestamp)
          notice(Timestamp < Timestamp)
          notice(Timestamp > Timestamp)
      CODE
      expect(eval_and_collect_notices(code)).to eq(%w(true true false false))
    end

    it 'does not consider an Integer to be an instance' do
      code = <<-CODE
        notice(assert_type(Timestamp, 1234))
      CODE
      expect { eval_and_collect_notices(code) }.to raise_error(/expects a Timestamp value, got Integer/)
    end

    it 'does not consider a Float to be an instance' do
      code = <<-CODE
        notice(assert_type(Timestamp, 1.234))
      CODE
      expect { eval_and_collect_notices(code) }.to raise_error(/expects a Timestamp value, got Float/)
    end

    context "when parameterized" do
      it 'is equal other types with the same parameterization' do
        code = <<-CODE
            notice(Timestamp['2015-03-01', '2016-01-01'] == Timestamp['2015-03-01', '2016-01-01'])
            notice(Timestamp['2015-03-01', '2016-01-01'] != Timestamp['2015-11-03', '2016-12-24'])
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true true))
      end

      it 'using just one parameter is the same as using default for the second parameter' do
        code = <<-CODE
            notice(Timestamp['2015-03-01'] == Timestamp['2015-03-01', default])
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true))
      end

      it 'if the second parameter is default, it is unlimited' do
        code = <<-CODE
            notice(Timestamp('5553-12-31') =~ Timestamp['2015-03-01', default])
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true))
      end

      it 'orders parameterized types based on range inclusion' do
        code = <<-CODE
            notice(Timestamp['2015-03-01', '2015-09-30'] < Timestamp['2015-02-01', '2015-10-30'])
            notice(Timestamp['2015-03-01', '2015-09-30'] > Timestamp['2015-02-01', '2015-10-30'])
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true false))
      end
    end

    context 'a Timestamp instance' do
      it 'can be created from a string with just a date' do
        code = <<-CODE
            $o = Timestamp('2015-03-01')
            notice($o)
            notice(type($o))
        CODE
        expect(eval_and_collect_notices(code)).to eq(['2015-03-01T00:00:00.000000000 UTC', "Timestamp['2015-03-01T00:00:00.000000000 UTC']"])
      end

      it 'can be created from a string and time separated by "T"' do
        code = <<-CODE
            notice(Timestamp('2015-03-01T11:12:13'))
        CODE
        expect(eval_and_collect_notices(code)).to eq(['2015-03-01T11:12:13.000000000 UTC'])
      end

      it 'can be created from a string and time separated by space' do
        code = <<-CODE
            notice(Timestamp('2015-03-01 11:12:13'))
        CODE
        expect(eval_and_collect_notices(code)).to eq(['2015-03-01T11:12:13.000000000 UTC'])
      end

      it 'should error when none of the default formats can parse the string' do
        code = <<-CODE
            notice(Timestamp('2015#03#01 11:12:13'))
        CODE
        expect { eval_and_collect_notices(code) }.to raise_error(/Unable to parse/)
      end

      it 'should error when only part of the string is parsed' do
        code = <<-CODE
            notice(Timestamp('2015-03-01T11:12:13 bogus after'))
        CODE
        expect { eval_and_collect_notices(code) }.to raise_error(/Unable to parse/)
      end

      it 'can be created from a string and format' do
        code = <<-CODE
            $o = Timestamp('Sunday, 28 August, 2016', '%A, %d %B, %Y')
            notice($o)
        CODE
        expect(eval_and_collect_notices(code)).to eq(['2016-08-28T00:00:00.000000000 UTC'])
      end

      it 'can be created from a string, format, and a timezone' do
        code = <<-CODE
            $o = Timestamp('Sunday, 28 August, 2016', '%A, %d %B, %Y', 'EST')
            notice($o)
        CODE
        expect(eval_and_collect_notices(code)).to eq(['2016-08-28T05:00:00.000000000 UTC'])
      end

      it 'can be not be created from a string, format with timezone designator, and a timezone' do
        code = <<-CODE
            $o = Timestamp('Sunday, 28 August, 2016 UTC', '%A, %d %B, %Y %z', 'EST')
            notice($o)
        CODE
        expect { eval_and_collect_notices(code) }.to raise_error(
          /Using a Timezone designator in format specification is mutually exclusive to providing an explicit timezone argument/)
      end

      it 'can be created from a hash with string and format' do
        code = <<-CODE
            $o = Timestamp({ string => 'Sunday, 28 August, 2016', format => '%A, %d %B, %Y' })
            notice($o)
        CODE
        expect(eval_and_collect_notices(code)).to eq(['2016-08-28T00:00:00.000000000 UTC'])
      end

      it 'can be created from a hash with string, format, and a timezone' do
        code = <<-CODE
            $o = Timestamp({ string => 'Sunday, 28 August, 2016', format => '%A, %d %B, %Y', timezone => 'EST' })
            notice($o)
        CODE
        expect(eval_and_collect_notices(code)).to eq(['2016-08-28T05:00:00.000000000 UTC'])
      end

      it 'can be created from a string and array of formats' do
        code = <<-CODE
            $fmts = [
              '%A, %d %B, %Y at %r',
              '%b %d, %Y, %l:%M %P',
              '%y-%m-%d %H:%M:%S %z'
            ]
            notice(Timestamp('Sunday, 28 August, 2016 at 12:15:00 PM', $fmts))
            notice(Timestamp('Jul 24, 2016, 1:20 am', $fmts))
            notice(Timestamp('16-06-21 18:23:15 UTC', $fmts))
        CODE
        expect(eval_and_collect_notices(code)).to eq(
          ['2016-08-28T12:15:00.000000000 UTC', '2016-07-24T01:20:00.000000000 UTC', '2016-06-21T18:23:15.000000000 UTC'])
      end

      it 'it cannot be created using an empty formats array' do
        code = <<-CODE
            notice(Timestamp('2015-03-01T11:12:13', []))
        CODE
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /parameter 'format' variant 1 expects size to be at least 1, got 0/)
      end

      it 'can be created from a string, array of formats, and a timezone' do
        code = <<-CODE
            $fmts = [
              '%A, %d %B, %Y at %r',
              '%b %d, %Y, %l:%M %P',
              '%y-%m-%d %H:%M:%S'
            ]
            notice(Timestamp('Sunday, 28 August, 2016 at 12:15:00 PM', $fmts, 'CET'))
            notice(Timestamp('Jul 24, 2016, 1:20 am', $fmts, 'CET'))
            notice(Timestamp('16-06-21 18:23:15', $fmts, 'CET'))
        CODE
        expect(eval_and_collect_notices(code)).to eq(
          ['2016-08-28T11:15:00.000000000 UTC', '2016-07-24T00:20:00.000000000 UTC', '2016-06-21T17:23:15.000000000 UTC'])
      end

      it 'can be created from a integer that represents seconds since epoch' do
        code = <<-CODE
            $o = Timestamp(1433116800)
            notice(Integer($o) == 1433116800)
            notice($o == Timestamp('2015-06-01T00:00:00 UTC'))
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true true))
      end

      it 'can be created from a float that represents seconds with fraction since epoch' do
        code = <<-CODE
            $o = Timestamp(1433116800.123456)
            notice(Float($o) == 1433116800.123456)
            notice($o == Timestamp('2015-06-01T00:00:00.123456 UTC'))
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true true))
      end

      it 'matches the appropriate parameterized type' do
        code = <<-CODE
            $o = Timestamp('2015-05-01')
            notice(assert_type(Timestamp['2015-03-01', '2015-09-30'], $o))
         CODE
        expect(eval_and_collect_notices(code)).to eq(['2015-05-01T00:00:00.000000000 UTC'])
      end

      it 'does not match an inappropriate parameterized type' do
        code = <<-CODE
            $o = Timestamp('2015-05-01')
            notice(assert_type(Timestamp['2016-03-01', '2016-09-30'], $o) |$e, $a| { 'nope' })
        CODE
        expect(eval_and_collect_notices(code)).to eq(['nope'])
      end

      it 'can be compared to other instances' do
        code = <<-CODE
            $o1 = Timestamp('2015-05-01')
            $o2 = Timestamp('2015-06-01')
            $o3 = Timestamp('2015-06-01')
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

      it 'can be compared to integer that represents seconds since epoch' do
        code = <<-CODE
            $o1 = Timestamp('2015-05-01')
            $o2 = Timestamp('2015-06-01')
            $o3 = 1433116800
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

      it 'integer that represents seconds since epoch can be compared to it' do
        code = <<-CODE
            $o1 = 1430438400
            $o2 = 1433116800
            $o3 = Timestamp('2015-06-01')
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

      it 'is equal to integer that represents seconds since epoch' do
        code = <<-CODE
            $o1 = Timestamp('2015-06-01T00:00:00 UTC')
            $o2 = 1433116800
            notice($o1 == $o2)
            notice($o1 != $o2)
            notice(Integer($o1) == $o2)
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true false true))
      end

      it 'integer that represents seconds is equal to it' do
        code = <<-CODE
            $o1 = 1433116800
            $o2 = Timestamp('2015-06-01T00:00:00 UTC')
            notice($o1 == $o2)
            notice($o1 != $o2)
            notice($o1 == Integer($o2))
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true false true))
      end

      it 'can be compared to float that represents seconds with fraction since epoch' do
        code = <<-CODE
            $o1 = Timestamp('2015-05-01T00:00:00.123456789 UTC')
            $o2 = Timestamp('2015-06-01T00:00:00.123456789 UTC')
            $o3 = 1433116800.123456789
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

      it 'float that represents seconds with fraction since epoch can be compared to it' do
        code = <<-CODE
            $o1 = 1430438400.123456789
            $o2 = 1433116800.123456789
            $o3 = Timestamp('2015-06-01T00:00:00.123456789 UTC')
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

      it 'is equal to float that represents seconds with fraction since epoch' do
        code = <<-CODE
            $o1 = Timestamp('2015-06-01T00:00:00.123456789 UTC')
            $o2 = 1433116800.123456789
            notice($o1 == $o2)
            notice($o1 != $o2)
            notice(Float($o1) == $o2)
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true false true))
      end

      it 'float that represents seconds with fraction is equal to it' do
        code = <<-CODE
            $o1 = 1433116800.123456789
            $o2 = Timestamp('2015-06-01T00:00:00.123456789 UTC')
            notice($o1 == $o2)
            notice($o1 != $o2)
            notice($o1 == Float($o2))
        CODE
        expect(eval_and_collect_notices(code)).to eq(%w(true false true))
      end

      it 'it cannot be compared to a Timespan' do
        code = <<-CODE
            notice(Timestamp() > Timespan(3))
        CODE
        expect { eval_and_collect_notices(code) }.to raise_error(Puppet::Error, /Timestamps are only comparable to Timestamps, Integers, and Floats/)
      end
    end
  end
end
end
end
