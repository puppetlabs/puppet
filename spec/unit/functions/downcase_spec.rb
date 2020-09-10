require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the downcase function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  it 'returns lower case version of a string' do
    expect(compile_to_catalog("notify { 'ABC'.downcase: }")).to have_resource('Notify[abc]')
  end

  it 'returns the value if Numeric' do
    expect(compile_to_catalog("notify { String(42.downcase == 42): }")).to have_resource('Notify[true]')
  end

  it 'performs downcase of international UTF-8 characters' do
    expect(compile_to_catalog("notify { 'ÅÄÖ'.downcase: }")).to have_resource('Notify[åäö]')
  end

  it 'returns lower case version of each entry in an array (recursively)' do
    expect(compile_to_catalog("notify { String(['A', ['B', ['C']]].downcase == ['a', ['b', ['c']]]): }")).to have_resource('Notify[true]')
  end

  it 'returns lower case version of keys and values in a hash (recursively)' do
    expect(compile_to_catalog("notify { String({'A'=>'B','C'=>{'D'=>'E'}}.downcase == {'a'=>'b', 'c'=>{'d'=>'e'}}): }")).to have_resource('Notify[true]')
  end

  it 'returns lower case version of keys and values in nested hash / array structure' do
    expect(compile_to_catalog("notify { String({'A'=>['B'],'C'=>[{'D'=>'E'}]}.downcase == {'a'=>['b'],'c'=>[{'d'=>'e'}]}): }")).to have_resource('Notify[true]')
  end

end
