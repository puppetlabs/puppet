require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the lstrip function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  it 'removes leading whitepsace' do
    expect(compile_to_catalog("notify { String(\"\t\n abc \".lstrip == 'abc '): }")).to have_resource('Notify[true]')
  end

  it 'returns the value if Numeric' do
    expect(compile_to_catalog("notify { String(42.lstrip == 42): }")).to have_resource('Notify[true]')
  end

  it 'returns lstripped version of each entry in an array' do
    expect(compile_to_catalog("notify { String([' a ', ' b ', ' c '].lstrip == ['a ', 'b ', 'c ']): }")).to have_resource('Notify[true]')
  end

  it 'returns lstripped version of each entry in an Iterator' do
    expect(compile_to_catalog("notify { String([' a', ' b', ' c'].reverse_each.lstrip == ['c', 'b', 'a']): }")).to have_resource('Notify[true]')
  end

  it 'errors when given a a nested Array' do
    expect { compile_to_catalog("['a', 'b', ['c']].lstrip")}.to raise_error(/'lstrip' parameter 'arg' expects a value of type Numeric, String, or Iterable/)
  end

end
