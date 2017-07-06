#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/tag_set'

RSpec::Matchers.define :be_one_of do |*expected|
  match do |actual|
    expected.include? actual
  end

  failure_message do |actual|
    "expected #{actual.inspect} to be one of #{expected.map(&:inspect).join(' or ')}"
  end
end

describe Puppet::Util::TagSet do
  let(:set) { Puppet::Util::TagSet.new }

  it 'serializes to yaml as an array' do
    array = ['a', :b, 1, 5.4]
    set.merge(array)

    expect(Set.new(YAML.load(set.to_yaml))).to eq(Set.new(array))
  end

  it 'deserializes from a yaml array' do
    array = ['a', :b, 1, 5.4]

    expect(Puppet::Util::TagSet.from_yaml(array.to_yaml)).to eq(Puppet::Util::TagSet.new(array))
  end

  it 'round trips through pson' do
    array = ['a', 'b', 1, 5.4]
    set.merge(array)

    tes = Puppet::Util::TagSet.from_data_hash(PSON.parse(set.to_pson))
    expect(tes).to eq(set)
  end

  it 'can join its elements with a string separator' do
    array = ['a', 'b']
    set.merge(array)

    expect(set.join(', ')).to be_one_of('a, b', 'b, a')
  end
end
