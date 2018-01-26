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

  def test_timestamp_format(ctor_arg, format, expected)
    expect(eval_and_collect_notices("notice(strftime(Timestamp('#{ctor_arg}'), '#{format}'))")).to eql(["#{expected}"])
  end

  def test_timestamp_format_tz(ctor_arg, format, tz, expected)
    expect(eval_and_collect_notices("notice(strftime(Timestamp('#{ctor_arg}'), '#{format}', '#{tz}'))")).to eql(["#{expected}"])
  end

  def collect_log(code, node = Puppet::Node.new('foonode'))
    Puppet[:code] = code
    compiler = Puppet::Parser::Compiler.new(node)
    node.environment.check_for_reparse
    logs = []
    Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
      compiler.compile
    end
    logs
  end

  context 'when applied to a Timestamp' do
    it 'can format a timestamp with a format pattern' do
      test_timestamp_format('2016-09-23T13:14:15.123 UTC', '%Y-%m-%d %H:%M:%S.%L %z', '2016-09-23 13:14:15.123 +0000')
    end

    it 'can format a timestamp using a specific timezone' do
      test_timestamp_format_tz('2016-09-23T13:14:15.123 UTC', '%Y-%m-%d %H:%M:%S.%L %z', 'EST', '2016-09-23 08:14:15.123 -0500')
    end
  end

  context 'when used with dispatcher covering legacy stdlib API (String format, String timeszone = undef)' do
    it 'produces the current time when used with one argument' do
      before_eval = Time.now
      notices = eval_and_collect_notices("notice(strftime('%F %T'))")
      expect(notices).not_to be_empty
      expect(notices[0]).to match(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\z/)
      parsed_time = DateTime.strptime(notices[0], '%F %T').to_time
      expect(Time.now.to_i >= parsed_time.to_i && parsed_time.to_i >= before_eval.to_i).to be_truthy
    end

    it 'emits a deprecation warning when used with one argument' do
      log = collect_log("notice(strftime('%F %T'))")
      warnings = log.select { |log_entry| log_entry.level == :warning }.map { |log_entry| log_entry.message }
      expect(warnings).not_to be_empty
      expect(warnings[0]).to match(/The argument signature \(String format, \[String timezone\]\) is deprecated for #strftime/)
    end

    it 'produces the current time formatted with specific timezone when used with two arguments' do
      before_eval = Time.now
      notices = eval_and_collect_notices("notice(strftime('%F %T %:z', 'EST'))")
      expect(notices).not_to be_empty
      expect(notices[0]).to match(/\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} -05:00\z/)
      parsed_time = DateTime.strptime(notices[0], '%F %T %z').to_time
      expect(Time.now.to_i >= parsed_time.to_i && parsed_time.to_i >= before_eval.to_i).to be_truthy
    end

    it 'emits a deprecation warning when using legacy format with two arguments' do
      log = collect_log("notice(strftime('%F %T', 'EST'))")
      warnings = log.select { |log_entry| log_entry.level == :warning }.map { |log_entry| log_entry.message }
      expect(warnings).not_to be_empty
      expect(warnings[0]).to match(/The argument signature \(String format, \[String timezone\]\) is deprecated for #strftime/)
    end
  end
end

