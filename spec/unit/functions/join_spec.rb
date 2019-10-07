require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the join function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  it 'joins an array with empty string delimiter if delimiter is not given' do
    expect(compile_to_catalog("notify { join([1,2,3]): }")).to have_resource('Notify[123]')
  end

  it 'joins an array with given string delimiter' do
    expect(compile_to_catalog("notify { join([1,2,3],'x'): }")).to have_resource('Notify[1x2x3]')
  end

  it 'results in empty string if array is empty' do
    expect(compile_to_catalog('notify { "x${join([])}y": }')).to have_resource('Notify[xy]')
  end

  it 'flattens nested arrays' do
    expect(compile_to_catalog("notify { join([1,2,[3,4]]): }")).to have_resource('Notify[1234]')
  end

  it 'does not flatten arrays nested in hashes' do
    expect(compile_to_catalog("notify { join([1,2,{a => [3,4]}]): }")).to have_resource('Notify[12{"a"=>[3, 4]}]')
  end

  it 'formats nil/undef as empty string' do
    expect(compile_to_catalog('notify { join([undef, undef], "x"): }')).to have_resource('Notify[x]')
  end
end
