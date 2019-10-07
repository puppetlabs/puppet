require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the chomp function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  it 'removes line endings CR LF from a string' do
    expect(compile_to_catalog("notify { String(\"abc\r\n\".chomp == 'abc'): }")).to have_resource('Notify[true]')
  end

  it 'removes line ending CR from a string' do
    expect(compile_to_catalog("notify { String(\"abc\r\".chomp == 'abc'): }")).to have_resource('Notify[true]')
  end

  it 'removes line ending LF from a string' do
    expect(compile_to_catalog("notify { String(\"abc\n\".chomp == 'abc'): }")).to have_resource('Notify[true]')
  end

  it 'does not removes LF before CR line ending from a string' do
    expect(compile_to_catalog("notify { String(\"abc\n\r\".chomp == \"abc\n\"): }")).to have_resource('Notify[true]')
  end

  it 'returns empty string for an empty string' do
    expect(compile_to_catalog("notify { String(''.chomp == ''): }")).to have_resource('Notify[true]')
  end

  it 'returns the value if Numeric' do
    expect(compile_to_catalog("notify { String(42.chomp == 42): }")).to have_resource('Notify[true]')
  end

  it 'returns chomped version of each entry in an array' do
    expect(compile_to_catalog("notify { String([\"a\n\", \"b\n\", \"c\n\"].chomp == ['a', 'b', 'c']): }")).to have_resource('Notify[true]')
  end

  it 'returns chopped version of each entry in an Iterator' do
    expect(compile_to_catalog("notify { String([\"a\n\", \"b\n\", \"c\n\"].reverse_each.chomp == ['c', 'b', 'a']): }")).to have_resource('Notify[true]')
  end

  it 'errors when given a a nested Array' do
    expect { compile_to_catalog("['a', 'b', ['c']].chomp")}.to raise_error(/'chomp' parameter 'arg' expects a value of type Numeric, String, or Iterable/)
  end

end
