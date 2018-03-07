require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the flatten function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  let(:array_fmt) { { 'format' => "%(a", 'separator'=>""} }

  it 'returns flattened array of all its given arguments' do
    expect(compile_to_catalog("notify { String([1,[2,[3]]].flatten, Array => #{array_fmt}): }")).to have_resource('Notify[(123)]')
  end

  it 'accepts a single non array value which results in it being wrapped in an array' do
    expect(compile_to_catalog("notify { String(flatten(1), Array => #{array_fmt}): }")).to have_resource('Notify[(1)]')
  end

  it 'accepts a single array value - (which is a noop)' do
    expect(compile_to_catalog("notify { String(flatten([1]), Array => #{array_fmt}): }")).to have_resource('Notify[(1)]')
  end

  it 'it does not flatten a hash - it is a value that gets wrapped' do
    expect(compile_to_catalog("notify { String(flatten({a=>1}), Array => #{array_fmt}): }")).to have_resource("Notify[({'a' => 1})]")
  end

  it 'accepts mix of array and non array arguments and concatenates and flattens them' do
    expect(compile_to_catalog("notify { String(flatten([1],2,[[3,4]]), Array => #{array_fmt}): }")).to have_resource('Notify[(1234)]')
  end
end
