require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the upcase function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  it 'returns upper case version of a string' do
    expect(compile_to_catalog("notify { 'abc'.upcase: }")).to have_resource('Notify[ABC]')
  end

  it 'returns the value if Numeric' do
    expect(compile_to_catalog("notify { String(42.upcase == 42): }")).to have_resource('Notify[true]')
  end

  it 'performs upcase of international UTF-8 characters' do
    expect(compile_to_catalog("notify { 'åäö'.upcase: }")).to have_resource('Notify[ÅÄÖ]')
  end

  it 'returns upper case version of each entry in an array (recursively)' do
    expect(compile_to_catalog("notify { String(['a', ['b', ['c']]].upcase == ['A', ['B', ['C']]]): }")).to have_resource('Notify[true]')
  end

  it 'returns upper case version of keys and values in a hash (recursively)' do
    expect(compile_to_catalog("notify { String({'a'=>'b','c'=>{'d'=>'e'}}.upcase == {'A'=>'B', 'C'=>{'D'=>'E'}}): }")).to have_resource('Notify[true]')
  end

  it 'returns upper case version of keys and values in nested hash / array structure' do
    expect(compile_to_catalog("notify { String({'a'=>['b'],'c'=>[{'d'=>'e'}]}.upcase == {'A'=>['B'],'C'=>[{'D'=>'E'}]}): }")).to have_resource('Notify[true]')
  end

end
