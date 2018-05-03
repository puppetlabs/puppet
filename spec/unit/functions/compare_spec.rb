require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the compare function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  {
    [0, 1]     => -1,
    [1, 0]     => 1,
    [1, 1]     => 0,
    [0.0, 1.0] => -1,
    [1.0, 0.0] => 1,
    [1.0, 1.0] => 0,
    [0.0, 1]   => -1,
    [1.0, 0]   => 1,
    [1.0, 1]   => 0,
    [0, 1.0]   => -1,
    [1, 0.0]   => 1,
    [1, 1.0]   => 0,
  }.each_pair do |values, expected|
    it "compares numeric/numeric such that compare(#{values[0]}, #{values[1]}) returns #{expected}" do
      expect(compile_to_catalog("notify { String( compare(#{values[0]},#{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
    end
  end

  {
    ['"a"', '"b"'] => -1,
    ['"b"', '"a"'] => 1,
    ['"b"', '"b"'] => 0,
    ['"A"', '"b"'] => -1,
    ['"B"', '"a"'] => 1,
    ['"B"', '"b"'] => 0,
  }.each_pair do |values, expected|
    it "compares String values by default such that compare(#{values[0]}, #{values[1]}) returns #{expected}" do
      expect(compile_to_catalog("notify { String( compare(#{values[0]},#{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
    end

    it "compares String values with third true arg such that compare(#{values[0]}, #{values[1]}, true) returns #{expected}" do
      expect(compile_to_catalog("notify { String( compare(#{values[0]},#{values[1]}, true) == #{expected}): }")).to have_resource("Notify[true]")
    end
  end

  {
    ['"a"', '"b"'] => -1,
    ['"b"', '"a"'] => 1,
    ['"b"', '"b"'] => 0,
    ['"A"', '"b"'] => -1,
    ['"B"', '"a"'] => -1,
    ['"B"', '"b"'] => -1,
  }.each_pair do |values, expected|
    it "compares String values with third arg false such that compare(#{values[0]}, #{values[1]}, false) returns #{expected}" do
      expect(compile_to_catalog("notify { String( compare(#{values[0]},#{values[1]}, false) == #{expected}): }")).to have_resource("Notify[true]")
    end
  end

  {
    ["Semver('1.0.0')", "Semver('2.0.0')"] => -1,
    ["Semver('2.0.0')", "Semver('1.0.0')"] => 1,
    ["Semver('2.0.0')", "Semver('2.0.0')"] => 0,
  }.each_pair do |values, expected|
    it "compares Semver values such that compare(#{values[0]}, #{values[1]}) returns #{expected}" do
      expect(compile_to_catalog("notify { String( compare(#{values[0]},#{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
    end
  end

  {
    ["Timespan(1)", "Timespan(2)"] => -1,
    ["Timespan(2)", "Timespan(1)"] => 1,
    ["Timespan(1)", "Timespan(1)"] => 0,
    ["Timespan(1)", 2] => -1,
    ["Timespan(2)", 1] => 1,
    ["Timespan(1)", 1] => 0,
    [1, "Timespan(2)"] => -1,
    [2, "Timespan(1)"] => 1,
    [1, "Timespan(1)"] => 0,

    ["Timestamp(1)", "Timestamp(2)"] => -1,
    ["Timestamp(2)", "Timestamp(1)"] => 1,
    ["Timestamp(1)", "Timestamp(1)"] => 0,
    ["Timestamp(1)", 2] => -1,
    ["Timestamp(2)", 1] => 1,
    ["Timestamp(1)", 1] => 0,
    [1, "Timestamp(2)"] => -1,
    [2, "Timestamp(1)"] => 1,
    [1, "Timestamp(1)"] => 0,

  }.each_pair do |values, expected|
    it "compares time values such that compare(#{values[0]}, #{values[1]}) returns #{expected}" do
      expect(compile_to_catalog("notify { String( compare(#{values[0]},#{values[1]}) == #{expected}): }")).to have_resource("Notify[true]")
    end
  end

  context "errors when" do
    [ [true, false],
      ['/x/', '/x/'],
      ['undef', 'undef'],
      ['undef', 1],
      [1, 'undef'],
      [[1], [1]],
      [{'a' => 1}, {'b' => 1}],
    ].each do |a, b|
      it "given values of non comparable types #{a.class}, #{b.class}" do
        expect { compile_to_catalog("compare(#{a},#{b})")}.to raise_error(/Non comparable type/)
      end
    end

    [
      [10, '"hello"'],
      ['"hello"', 10],
      [10.0, '"hello"'],
      ['"hello"', 10.0],
      ['Timespan(1)', '"hello"'],
      ['Timestamp(1)', '"hello"'],
      ['Timespan(1)', 'Semver("1.2.3")'],
      ['Timestamp(1)', 'Semver("1.2.3")'],
    ].each do |a, b|
      it "given values of comparable, but incompatible types #{a.class}, #{b.class}" do
        expect { compile_to_catalog("compare(#{a},#{b})")}.to raise_error(/Can only compare values of the same type/)
      end
    end

      [
        [10, 10],
        [10.0, 10],
        ['Timespan(1)', 'Timespan(1)'],
        ['Timestamp(1)', 'Timestamp(1)'],
        ['Semver("1.2.3")', 'Semver("1.2.3")'],
      ].each do |a, b|
        it "given ignore case true when values are comparable, but not both being strings" do
          expect { compile_to_catalog("compare(#{a},#{b}, true)")}.to raise_error(/can only be used when comparing strings/)
        end
        it "given ignore case false when values are comparable, but not both being strings" do
          expect { compile_to_catalog("compare(#{a},#{b}, false)")}.to raise_error(/can only be used when comparing strings/)
        end
      end

      it "given more than three arguments" do
          expect { compile_to_catalog("compare('a','b', false, false)")}.to raise_error(/Accepts at most 3 arguments, got 4/)
      end
  end

  # Error if not the same except Timestamp and Timespan that accepts Numeric on either side
  # Error for non supported - Boolean, Regexp, etc
end
