require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the min function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  let(:logs) { [] }
  let(:warnings) { logs.select { |log| log.level == :warning }.map { |log| log.message } }

  it 'errors if not give at least one argument' do
    expect{ compile_to_catalog("min()") }.to raise_error(/Wrong number of arguments need at least one/)
  end

  context 'compares numbers' do
    { [0, 1]    => 0,
      [-1, 0]   => -1,
      [-1.0, 0] => -1.0,
    }.each_pair do |values, expected|
      it "called as min(#{values[0]}, #{values[1]}) results in the value #{expected}" do
        expect(compile_to_catalog("notify { String( min(#{values[0]}, #{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
      end
    end
  end

  context 'compares strings that are not numbers without deprecation warning' do
    it "string as number is deprecated" do
      Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
        expect(compile_to_catalog("notify { String( min('a', 'b') == 'a'): }")).to have_resource("Notify[true]")
      end
      expect(warnings).to_not include(/auto conversion of .* is deprecated/)
    end
  end

  context 'compares strings as numbers if possible and outputs deprecation warning' do
    {
      [20, "'100'"] => 20,
      ["'20'", "'100'"] => "'20'",
      ["'20'", 100] => "'20'",
      [20, "'100x'"] => "'100x'",
      ["20", "'100x'"] => "'100x'",
      ["'20x'", 100] => 100,
    }.each_pair do |values, expected|
      it "called as min(#{values[0]}, #{values[1]}) results in the value #{expected}" do
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          expect(compile_to_catalog("notify { String( min(#{values[0]}, #{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
        end
        expect(warnings).to include(/auto conversion of .* is deprecated/)
      end
    end

    {
      [20, "'1e2'"] => 20,
      [20, "'1E2'"] => 20,
      [20, "'10_0'"] => 20,
      [20, "'100.0'"] => 20,
    }.each_pair do |values, expected|
      it "called as min(#{values[0]}, #{values[1]}) results in the value #{expected}" do
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          expect(compile_to_catalog("notify { String( min(#{values[0]}, #{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
        end
        expect(warnings).to include(/auto conversion of .* is deprecated/)
      end
    end

  end

  context 'compares semver' do
    { ["Semver('2.0.0')", "Semver('10.0.0')"] => "Semver('2.0.0')",
      ["Semver('5.5.5')", "Semver('5.6.7')"]  => "Semver('5.5.5')",
    }.each_pair do |values, expected|
      it "called as min(#{values[0]}, #{values[1]}) results in the value #{expected}" do
        expect(compile_to_catalog("notify { String( min(#{values[0]}, #{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
      end
    end
  end

  context 'compares timespans' do
    { ["Timespan(2)", "Timespan(77.3)"] => "Timespan(2)",
      ["Timespan('1-00:00:00')", "Timespan('2-00:00:00')"]  => "Timespan('1-00:00:00')",
    }.each_pair do |values, expected|
      it "called as min(#{values[0]}, #{values[1]}) results in the value #{expected}" do
        expect(compile_to_catalog("notify { String( min(#{values[0]}, #{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
      end
    end
  end

  context 'compares timestamps' do
    { ["Timestamp(0)", "Timestamp(298922400)"] => "Timestamp(0)",
      ["Timestamp('1970-01-01T12:00:00.000')", "Timestamp('1979-06-22T18:00:00.000')"]  => "Timestamp('1970-01-01T12:00:00.000')",
    }.each_pair do |values, expected|
      it "called as min(#{values[0]}, #{values[1]}) results in the value #{expected}" do
        expect(compile_to_catalog("notify { String( min(#{values[0]}, #{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
      end
    end
  end

  context 'compares all except numeric and string by conversion to string (and issues deprecation warning)' do
    {
      [[20], "'a'"]                  => [20],             # before since '[' is before 'a'
      ["{'a' => 10}", "'|a'"]         => "{'a' => 10}",   # before since '{' is before '|'
      [false, 'fal']                 => "'fal'",          # 'fal' before since shorter than 'false'
      ['/b/', "'(?-mix:a)'"]         => "'(?-mix:a)'",    # because regexp to_s is a (?-mix:b) string
      ["Timestamp(1)", "'1556 a.d'"] => "'1556 a.d'",     # because timestamp to_s is a date-time string here starting with 1970
    }.each_pair do |values, expected|
      it "called as min(#{values[0]}, #{values[1]}) results in the value #{expected} and issues deprecation warning" do
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          expect(compile_to_catalog("notify { String( min(#{values[0]}, #{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
        end
        expect(warnings).to include(/auto conversion of .* is deprecated/)
      end
    end
  end

  it "accepts a lambda that takes over the comparison (here avoiding the string as number conversion)" do
    src = <<-SRC
      $val = min("2", "10") |$a, $b| { compare($a, $b) }
      notify { String( $val == "10"): }
    SRC
    expect(compile_to_catalog(src)).to have_resource("Notify[true]")
  end

  context 'compares entries in a single array argument as if they were splatted as individual args' do
    {
      [1,2,3] => 1,
      ["1", "2","3"] => "'1'",
      [1,"2",3] => 1,
    }.each_pair do |value, expected|
      it "called as max(#{value}) results in the value #{expected}" do
        src = "notify { String( min(#{value}) == #{expected}): }"
        expect(compile_to_catalog(src)).to have_resource("Notify[true]")
      end
    end

    {
      [1,2,3] => 1,
      ["10","2","3"] => "'10'",
      [1,"x",3] => "'x'",
    }.each_pair do |value, expected|
      it "called as max(#{value}) with a lambda using compare() results in the value #{expected}" do
        src = <<-"SRC"
        function n_after_s($a,$b) {
          case [$a, $b] {
            [String, Numeric]: { -1 }
            [Numeric, String]: { 1 }
            default: { compare($a, $b) }
          }
        }
        notify { String( min(#{value}) |$a,$b| {n_after_s($a,$b) } == #{expected}): }
        SRC
        expect(compile_to_catalog(src)).to have_resource("Notify[true]")
      end
    end

  end
end
