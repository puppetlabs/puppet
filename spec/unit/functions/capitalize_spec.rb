require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the capitalize function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  it 'returns initial char upper case version of a string' do
    expect(compile_to_catalog("notify { 'abc'.capitalize: }")).to have_resource('Notify[Abc]')
  end

  it 'returns the value if Numeric' do
    expect(compile_to_catalog("notify { String(42.capitalize == 42): }")).to have_resource('Notify[true]')
  end

  it 'performs capitalize of international UTF-8 characters' do
    expect(compile_to_catalog("notify { 'åäö'.capitalize: }")).to have_resource('Notify[Åäö]')
  end

  it 'returns capitalized version of each entry in an array' do
    expect(compile_to_catalog("notify { String(['aa', 'ba', 'ca'].capitalize == ['Aa', 'Ba', 'Ca']): }")).to have_resource('Notify[true]')
  end

  it 'returns capitalized version of each entry in an Iterator' do
    expect(compile_to_catalog("notify { String(['aa', 'ba', 'ca'].reverse_each.capitalize == ['Ca', 'Ba', 'Aa']): }")).to have_resource('Notify[true]')
  end

  it 'errors when given a a nested Array' do
    expect { compile_to_catalog("['a', 'b', ['c']].capitalize")}.to raise_error(/'capitalize' parameter 'arg' expects a value of type Numeric, String, or Iterable/)
  end

end
