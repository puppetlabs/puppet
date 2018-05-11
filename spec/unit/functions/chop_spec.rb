require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the chop function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  it 'removes last character in a string' do
    expect(compile_to_catalog("notify { String('abc'.chop == 'ab'): }")).to have_resource('Notify[true]')
  end

  it 'returns empty string for an empty string' do
    expect(compile_to_catalog("notify { String(''.chop == ''): }")).to have_resource('Notify[true]')
  end

  it 'removes both CR LF if both are the last characters in a string' do
    expect(compile_to_catalog("notify { String(\"abc\r\n\".chop == 'abc'): }")).to have_resource('Notify[true]')
  end

  it 'returns the value if Numeric' do
    expect(compile_to_catalog("notify { String(42.chop == 42): }")).to have_resource('Notify[true]')
  end

  it 'returns chopped version of each entry in an array' do
    expect(compile_to_catalog("notify { String(['aa', 'ba', 'ca'].chop == ['a', 'b', 'c']): }")).to have_resource('Notify[true]')
  end

  it 'returns chopped version of each entry in an Iterator' do
    expect(compile_to_catalog("notify { String(['aa', 'bb', 'cc'].reverse_each.chop == ['c', 'b', 'a']): }")).to have_resource('Notify[true]')
  end

  it 'errors when given a a nested Array' do
    expect { compile_to_catalog("['a', 'b', ['c']].chop")}.to raise_error(/'chop' parameter 'arg' expects a value of type Numeric, String, or Iterable/)
  end

end
