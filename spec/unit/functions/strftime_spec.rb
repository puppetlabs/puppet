require 'spec_helper'
require 'puppet_spec/compiler'

describe 'the strftime function' do
  include PuppetSpec::Compiler

  def test_format(ctor_arg, format, expected)
    expect(eval_and_collect_notices("notice(strftime(Timespan(#{ctor_arg}), '#{format}'))")).to eql(["#{expected}"])
  end

  context 'when applied to a Timespan' do
    [
      ['hours', 'H', 2],
      ['minutes', 'M', 2],
      ['seconds', 'S', 2],
    ].each do |field, fmt, dflt_width|
      ctor_arg = "{#{field}=>3}"
      it "%#{fmt} width defaults to #{dflt_width}" do
        test_format(ctor_arg, "%#{fmt}", sprintf("%0#{dflt_width}d", 3))
      end

      it "%_#{fmt} pads with space" do
        test_format(ctor_arg, "%_#{fmt}", sprintf("% #{dflt_width}d", 3))
      end

      it "%-#{fmt} does not pad" do
        test_format(ctor_arg, "%-#{fmt}", '3')
      end

      it "%10#{fmt} pads with zeroes to specified width" do
        test_format(ctor_arg, "%10#{fmt}", sprintf("%010d", 3))
      end

      it "%_10#{fmt} pads with space to specified width" do
        test_format(ctor_arg, "%_10#{fmt}", sprintf("% 10d", 3))
      end

      it "%-10#{fmt} does not pad even if width is specified" do
        test_format(ctor_arg, "%-10#{fmt}", '3')
      end
    end

    [
      ['milliseconds', 'L', 3],
      ['nanoseconds', 'N', 9],
      ['milliseconds', '3N', 3],
      ['microseconds', '6N', 6],
      ['nanoseconds', '9N', 9],
    ].each do |field, fmt, dflt_width|
      ctor_arg = "{#{field}=>3000}"
      it "%#{fmt} width defaults to #{dflt_width}" do
        test_format(ctor_arg, "%#{fmt}", sprintf("%-#{dflt_width}d", 3000))
      end

      it "%_#{fmt} pads with space" do
        test_format(ctor_arg, "%_#{fmt}", sprintf("%-#{dflt_width}d", 3000))
      end

      it "%-#{fmt} does not pad" do
        test_format(ctor_arg, "%-#{fmt}", '3000')
      end
    end

    it 'can use a format containing all format characters, flags, and widths' do
      test_format("{string => '100-14:02:24.123456000', format => '%D-%H:%M:%S.%9N'}", '%_10D%%%03H:%-M:%S.%9N', '       100%014:2:24.123456000')
    end

    it 'can format and strip excess zeroes from fragment using no-padding flag' do
      test_format("{string => '100-14:02:24.123456000', format => '%D-%H:%M:%S.%N'}", '%D-%H:%M:%S.%-N', '100-14:02:24.123456')
    end

    it 'can format and replace excess zeroes with spaces from fragment using space-padding flag and default widht' do
      test_format("{string => '100-14:02:24.123456000', format => '%D-%H:%M:%S.%N'}", '%D-%H:%M:%S.%_N', '100-14:02:24.123456   ')
    end

    it 'can format and replace excess zeroes with spaces from fragment using space-padding flag and specified width' do
      test_format("{string => '100-14:02:24.123400000', format => '%D-%H:%M:%S.%N'}", '%D-%H:%M:%S.%_6N', '100-14:02:24.1234  ')
    end

    it 'can format and retain excess zeroes in fragment using default width' do
      test_format("{string => '100-14:02:24.123400000', format => '%D-%H:%M:%S.%N'}", '%D-%H:%M:%S.%N', '100-14:02:24.123400000')
    end

    it 'can format and retain excess zeroes in fragment using specified width' do
      test_format("{string => '100-14:02:24.123400000', format => '%D-%H:%M:%S.%N'}", '%D-%H:%M:%S.%6N', '100-14:02:24.123400')
    end
  end
end

