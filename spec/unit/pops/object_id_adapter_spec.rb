#! /usr/bin/env ruby
require 'spec_helper'

describe 'the ObjectIdCacheAdapter' do
  let(:adapted) { Object.new }
  let(:adapter) { Puppet::Pops::Adapters::ObjectIdCacheAdapter.adapt(adapted) }

  it 'can be created (like all other adapters)' do
    expect(adapter).to be_a(Puppet::Pops::Adapters::ObjectIdCacheAdapter)
  end

  it 'the insert method adds/overwrites a value in the cache' do
    x = adapter.insert(adapted, :key, 40)
    x = adapter.insert(adapted, :key, 42)
    expect(x).to eql(42)
    y = adapter.get(adapted, :key)
    expect(y).to eql(42)
  end

  it 'the get method gets a value in the cache' do
    adapter.insert(adapted, :key, 40)
    expect(adapter.get(adapted, :key)).to eql(40)
  end

  context 'the clear method' do
    it 'removes all values from cache' do
      adapter.insert(adapted, :key1, 40)
      adapter.insert(adapted, :key2, 41)
      adapter.clear(adapted)
      expect(adapter.get(adapted, :key1)).to be_nil
      expect(adapter.get(adapted, :key2)).to be_nil
    end

    it 'calls a given block with each value' do
      guard = Object.new
      guard.expects(:check).with(:key1, 40).once
      guard.expects(:check).with(:key2, 41).once

      adapter.insert(adapted, :key1, 40)
      adapter.insert(adapted, :key2, 41)
      adapter.clear(adapted) {|k, v| guard.check(k, v) }
    end
  end

  it 'the add method adds a value in the cache if not already added' do
    x = adapter.add(adapted, :key) { 42 }
    guard = Object.new
    guard.expects(:check).never
    x = adapter.add(adapted, :key) { guard.check }
    expect(x).to eql(42)
    y = adapter.get(adapted, :key)
    expect(y).to eql(42)
  end

  it 'the replace method replaces old value with new and passes old value to lambda' do
    # expect an initial replace to get nil value for old
    adapter.replace(adapted, :key) { |old|
      expect(old).to be_nil
      "don't want to see this value later" # set this for now, should be overwritten
    }
    # overwrite it
    x = adapter.insert(adapted, :key, 42)
    adapter.replace(adapted, :key) { |old|
      expect(old).to eql(42)
      43 # the replacement
    }
    expect(x).to eql(42)
    y = adapter.get(adapted, :key)
    expect(y).to eql(43)
  end

  it 'the retrieve method returns the entire hash for the cache_id' do
    adapter.insert(adapted, :key1, 40)
    adapter.insert(adapted, :key2, 41)
    expect(adapter.retrieve(adapted)).to eql(:key1 => 40, :key2 => 41)
  end

end