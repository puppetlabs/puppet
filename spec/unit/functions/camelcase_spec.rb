require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the camelcase function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  it 'replaces initial <char> and each _<char> with upper case version of the char' do
    expect(compile_to_catalog("notify { 'abc_def'.camelcase: }")).to have_resource('Notify[AbcDef]')
  end

  it 'returns the value if Numeric' do
    expect(compile_to_catalog("notify { String(42.camelcase == 42): }")).to have_resource('Notify[true]')
  end

  it 'performs camelcase of international UTF-8 characters' do
    expect(compile_to_catalog("notify { 'åäö_äö'.camelcase: }")).to have_resource('Notify[ÅäöÄö]')
  end

  it 'returns capitalized version of each entry in an array' do
    expect(compile_to_catalog("notify { String(['a_a', 'b_a', 'c_a'].camelcase == ['AA', 'BA', 'CA']): }")).to have_resource('Notify[true]')
  end

  it 'returns capitalized version of each entry in an Iterator' do
    expect(compile_to_catalog("notify { String(['a_a', 'b_a', 'c_a'].reverse_each.camelcase == ['CA', 'BA', 'AA']): }")).to have_resource('Notify[true]')
  end

  it 'errors when given a a nested Array' do
    expect { compile_to_catalog("['a', 'b', ['c']].camelcase")}.to raise_error(/'camelcase' parameter 'arg' expects a value of type Numeric, String, or Iterable/)
  end

end
