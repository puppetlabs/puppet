require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the max function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  let(:logs) { [] }
  let(:warnings) { logs.select { |log| log.level == :warning }.map { |log| log.message } }

  it 'errors if not give at least one argument' do
    expect{ compile_to_catalog("max()") }.to raise_error(/Wrong number of arguments need at least one/)
  end

  context 'compares numbers' do
    { [0, 1]    => 1,
      [-1, 0]   => 0,
      [-1.0, 0] => 0,
    }.each_pair do |values, expected|
      it "called as max(#{values[0]}, #{values[1]}) results in the value #{expected}" do
        expect(compile_to_catalog("notify { String( max(#{values[0]}, #{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
      end
    end
  end

  context 'compares strings that are not numbers without deprecation warning' do
    it "string as number is deprecated" do
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        expect(compile_to_catalog("notify { String( max('a', 'b') == 'b'): }")).to have_resource("Notify[true]")
      end
      expect(warnings).to_not include(/auto conversion of .* is deprecated/)
    end
  end

  context 'compares strings as numbers if possible and issues deprecation warning' do
    {
      [20, "'100'"]     => "'100'",
      ["'20'", "'100'"] => "'100'",
      ["'20'", 100]     => "100",
      [20, "'100x'"]    => "20",
      ["20", "'100x'"]  => "20",
      ["'20x'", 100]    => "'20x'",
    }.each_pair do |values, expected|
      it "called as max(#{values[0]}, #{values[1]}) results in the value #{expected}" do
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          expect(compile_to_catalog("notify { String( max(#{values[0]}, #{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
        end
        expect(warnings).to include(/auto conversion of .* is deprecated/)
      end
    end

    {
      [20, "'1e2'"] => "'1e2'",
      [20, "'1E2'"] => "'1E2'",
      [20, "'10_0'"] => "'10_0'",
      [20, "'100.0'"] => "'100.0'",
    }.each_pair do |values, expected|
      it "called as max(#{values[0]}, #{values[1]}) results in the value #{expected}" do
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          expect(compile_to_catalog("notify { String( max(#{values[0]}, #{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
        end
        expect(warnings).to include(/auto conversion of .* is deprecated/)
      end
    end

  end

  context 'compares semver' do
    { ["Semver('2.0.0')", "Semver('10.0.0')"] => "Semver('10.0.0')",
      ["Semver('5.5.5')", "Semver('5.6.7')"]  => "Semver('5.6.7')",
    }.each_pair do |values, expected|
      it "called as max(#{values[0]}, #{values[1]}) results in the value #{expected}" do
        expect(compile_to_catalog("notify { String( max(#{values[0]}, #{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
      end
    end
  end

  context 'compares timespans' do
    { ["Timespan(2)", "Timespan(77.3)"] => "Timespan(77.3)",
      ["Timespan('1-00:00:00')", "Timespan('2-00:00:00')"]  => "Timespan('2-00:00:00')",
    }.each_pair do |values, expected|
      it "called as max(#{values[0]}, #{values[1]}) results in the value #{expected}" do
        expect(compile_to_catalog("notify { String( max(#{values[0]}, #{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
      end
    end
  end

  context 'compares timestamps' do
    { ["Timestamp(0)", "Timestamp(298922400)"] => "Timestamp(298922400)",
      ["Timestamp('1970-01-01T12:00:00.000')", "Timestamp('1979-06-22T18:00:00.000')"]  => "Timestamp('1979-06-22T18:00:00.000')",
    }.each_pair do |values, expected|
      it "called as max(#{values[0]}, #{values[1]}) results in the value #{expected}" do
        expect(compile_to_catalog("notify { String( max(#{values[0]}, #{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
      end
    end
  end

  context 'compares all except numeric and string by conversion to string and issues deprecation warning' do
    {
      [[20], "'a'"]                  => "'a'",            # after since '[' is before 'a'
      ["{'a' => 10}", "'a'"]         => "{'a' => 10}",    # after since '{' is after 'a'
      [false, 'fal']                 => "false",          # the boolean since text 'false' is longer
      ['/b/', "'(?-mix:c)'"]         => "'(?-mix:c)'",    # because regexp to_s is a (?-mix:b) string
      ["Timestamp(1)", "'1980 a.d'"] => "'1980 a.d'",     # because timestamp to_s is a date-time string here starting with 1970
    }.each_pair do |values, expected|
      it "called as max(#{values[0]}, #{values[1]}) results in the value #{expected} and issues deprecation warning" do
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          expect(compile_to_catalog("notify { String( max(#{values[0]}, #{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
        end
        expect(warnings).to include(/auto conversion of .* is deprecated/)
      end
    end
  end

  it "accepts a lambda that takes over the comparison (here avoiding the string as number conversion)" do
    src = <<-SRC
      $val = max("2", "10") |$a, $b| { compare($a, $b) }
      notify { String( $val == "2"): }
    SRC
    expect(compile_to_catalog(src)).to have_resource("Notify[true]")
  end

  context 'compares entries in a single array argument as if they were splatted as individual args' do
    {
      [1,2,3] => 3,
      ["1", "2","3"] => "'3'",
      [1, "2", 3] => 3,
    }.each_pair do |value, expected|
      it "called as max(#{value}) results in the value #{expected}" do
        src = "notify { String( max(#{value}) == #{expected}): }"
        expect(compile_to_catalog(src)).to have_resource("Notify[true]")
      end
    end

    {
      [1,2,3] => 3,
      ["10","2","3"] => "'3'",
      [1,"x",3] => "'x'",
    }.each_pair do |value, expected|
      it "called as max(#{value}) with a lambda using compare() results in the value #{expected}" do
        src = <<-"SRC"
        function s_after_n($a,$b) {
          case [$a, $b] {
            [String, Numeric]: { 1 }
            [Numeric, String]: { -1 }
            default: { compare($a, $b) }
          }
        }
        notify { String( max(#{value}) |$a,$b| {s_after_n($a,$b) } == #{expected}): }
        SRC
        expect(compile_to_catalog(src)).to have_resource("Notify[true]")
      end
    end

  end
end
