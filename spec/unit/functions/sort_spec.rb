require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the sort function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

    {
      "'bac'"     => "'abc'",
      "'BaC'"     => "'BCa'",
    }.each_pair do |value, expected|
      it "sorts characters in a string such that #{value}.sort results in #{expected}" do
        expect(compile_to_catalog("notify { String( sort(#{value}) == #{expected}): }")).to have_resource("Notify[true]")
      end
    end

  {
     "'bac'"     => "'abc'",
     "'BaC'"     => "'aBC'",
   }.each_pair do |value, expected|
     it "accepts a lambda when sorting characters in a string such that #{value} results in #{expected}" do
       expect(compile_to_catalog("notify { String( sort(#{value}) |$a,$b| { compare($a,$b) } == #{expected}): }")).to have_resource("Notify[true]")
     end
   end

  {
    ['b', 'a', 'c']     => ['a', 'b', 'c'],
    ['B', 'a', 'C']     => ['B', 'C', 'a'],
  }.each_pair do |value, expected|
    it "sorts strings in an array such that #{value}.sort results in #{expected}" do
      expect(compile_to_catalog("notify { String( sort(#{value}) == #{expected}): }")).to have_resource("Notify[true]")
    end
  end

  {
    ['b', 'a', 'c']     => ['a', 'b', 'c'],
    ['B', 'a', 'C']     => ['a', 'B', 'C'],
  }.each_pair do |value, expected|
    it "accepts a lambda when sorting an array such that #{value} results in #{expected}" do
      expect(compile_to_catalog("notify { String( sort(#{value}) |$a,$b| { compare($a,$b) } == #{expected}): }")).to have_resource("Notify[true]")
    end
  end

  it 'errors if given a mix of data types' do
    expect { compile_to_catalog("sort([1, 'a'])")}.to raise_error(/comparison .* failed/)
  end

  it 'returns empty string for empty string input' do
    expect(compile_to_catalog("notify { String(sort('') == ''): }")).to have_resource("Notify[true]")
  end

  it 'returns empty string for empty string input' do
    expect(compile_to_catalog("notify { String(sort([]) == []): }")).to have_resource("Notify[true]")
  end

  it 'can sort mixed data types when using a lambda' do
    # source sorts Numeric before string and uses compare() for same data type
    src = <<-SRC
    notify{ String(sort(['b', 3, 'a', 2]) |$a, $b| {
        case [$a, $b] {
          [String, Numeric] : { 1 }
          [Numeric, String] : { -1 }
          default:            { compare($a, $b) }
        }
      } == [2, 3,'a', 'b']):
    }
    SRC
    expect(compile_to_catalog(src)).to have_resource("Notify[true]")

  end

  it 'errors if lambda does not accept 2 arguments' do
    expect { compile_to_catalog("sort([1, 'a']) || { }")}.to raise_error(/block expects 2 arguments/)
    expect { compile_to_catalog("sort([1, 'a']) |$x| { }")}.to raise_error(/block expects 2 arguments/)
    expect { compile_to_catalog("sort([1, 'a']) |$x,$y, $z| { }")}.to raise_error(/block expects 2 arguments/)
  end
end
