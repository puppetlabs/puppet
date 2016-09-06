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
      ['milli_seconds', 'L', 3],
      ['nano_seconds', 'N', 9],
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
      ['milli_seconds', '3N', 3],
      ['micro_seconds', '6N', 6],
      ['nano_seconds', '9N', 9],
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
    end

    it 'can use a format containing all format characters, flags, and widths' do
      test_format("{string => '100-14:02:24.123456789', format => '%D-%H:%M:%S.%9N'}", '%_10D%%%03H:%-M:%S.%9N', '       100%014:2:24.123456789')
    end
  end
end

