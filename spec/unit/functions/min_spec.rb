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

  context 'compares strings as numbers if possible (deprecated)' do
    {
      [20, "'100'"] => 20,
      ["'20'", "'100'"] => "'20'",
      ["'20'", 100] => "'20'",
      [20, "'100x'"] => "'100x'",
      ["20", "'100x'"] => "'100x'",
      ["'20x'", 100] => 100,
    }.each_pair do |values, expected|
      it "called as min(#{values[0]}, #{values[1]}) results in the value #{expected} and issues deprecation warning" do
        Puppet::Util::Log.with_destination(Puppet::Test::LogCollector.new(logs)) do
          expect(compile_to_catalog("notify { String( min(#{values[0]}, #{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
        end
        expect(warnings).to include(/auto conversion of .* is deprecated/)
      end
    end
  end

  context 'compares all except numeric and string by conversion to string (deprecated)' do
    {
      [[20], "'a'"]                  => [20],             # before since '[' is before 'a'
      ["{'a' => 10}", "'|a'"]         => "{'a' => 10}",   # before since '{' is before '|'
      [false, 'fal']                 => "'fal'",          # 'fal' before since shorter than 'false'
      ['/b/', "'(?-mix:a)'"]         => "'(?-mix:a)'",    # because regexp to_s is a (?-mix:b) string
      ["Timestamp(1)", "'1556 a.d'"] => "'1556 a.d'",     # because timestamp to_s is a date-time string here starting with 1970
      ["Semver('2.0.0')", "Semver('10.0.0')"] => "Semver('10.0.0')", # "10.0.0" is lexicographically before "2.0.0"
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

end
