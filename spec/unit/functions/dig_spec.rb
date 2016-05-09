require 'spec_helper'

require 'puppet_spec/compiler'
require 'matchers/resource'

describe 'the dig function' do
  include PuppetSpec::Compiler
  include Matchers::Resource

  it 'returns a value from an array index via integer index' do
    expect(compile_to_catalog("notify { [testing].dig(0): }")).to have_resource('Notify[testing]')
  end

  it 'returns undef if given an undef key' do
  expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[test-Undef-ing]')
    notify { "test-${type([testing].dig(undef))}-ing": }
    SOURCE
  end

  it 'returns undef if starting with undef' do
  expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[test-Undef-ing]')
    notify { "test-${type(undef.dig(undef))}-ing": }
    SOURCE
  end

  it 'returns a value from an hash key via given key' do
    expect(compile_to_catalog("notify { {key => testing}.dig(key): }")).to have_resource('Notify[testing]')
  end

  it 'continues digging if result is an array' do
    expect(compile_to_catalog("notify { [nope, [testing]].dig(1, 0): }")).to have_resource('Notify[testing]')
  end

  it 'continues digging if result is a hash' do
    expect(compile_to_catalog("notify { [nope, {yes => testing}].dig(1, yes): }")).to have_resource('Notify[testing]')
  end

  it 'stops digging when step is undef' do
    expect(compile_to_catalog(<<-SOURCE)).to have_resource('Notify[testing]')
    $result = [nope, {yes => testing}].dig(1, no, 2)
    notify { "test${result}ing": }
    SOURCE
  end

  it 'errors if step is neither Array nor Hash' do
    expect { compile_to_catalog(<<-SOURCE)}.to raise_error(/The given data does not contain a Collection at \[1, "yes"\], got 'String'/)
    $result = [nope, {yes => testing}].dig(1, yes, 2)
    notify { "test${result}ing": }
    SOURCE
  end

  it 'errors if not given a non Collection as the starting point' do
    expect { compile_to_catalog(<<-SOURCE)}.to raise_error(/'dig' parameter 'data' expects a Collection value, got String/)
    "hello".dig(1, yes, 2)
    SOURCE
  end

end
