require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the type function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  it 'produces the type of a given value with default detailed quality' do
  expect(compile_to_catalog('notify { "${ type([2, 3.14]) }": }')).to have_resource(
      'Notify[Tuple[Integer[2, 2], Float[3.14, 3.14]]]')
  end

  it 'produces the type of a give value with detailed quality when quality is given' do
    expect(compile_to_catalog('notify { "${ type([2, 3.14], detailed) }": }')).to have_resource(
      'Notify[Tuple[Integer[2, 2], Float[3.14, 3.14]]]')
  end

  it 'produces the type of a given value with reduced quality when quality is given' do
    expect(compile_to_catalog('notify { "${ type([2, 3.14], reduced) }": }')).to have_resource(
      'Notify[Array[Numeric, 2, 2]]')
  end

  it 'produces the type of a given value with generalized quality when quality is given' do
    expect(compile_to_catalog('notify { "${ type([2, 3.14], generalized) }": }')).to have_resource(
      'Notify[Array[Numeric]]')
  end

  it 'errors when given a fault inference quality' do
    expect do
      compile_to_catalog("notify { type([2, 4.14], gobbledygooked): }")
    end.to raise_error(/expects a match for Enum\['detailed', 'generalized', 'reduced'\], got 'gobbledygooked'/)
  end
end
