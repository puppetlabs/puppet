#! /usr/bin/env ruby
require 'spec_helper'

describe "The Util::MultiMatch" do
  let(:not_nil) { MultiMatch::NOT_NIL }

  it "matches against not nil" do
    expect(not_nil === 3).to be(true)
  end

  it "matches against multiple values" do
    expect(MultiMatch.new(not_nil, not_nil) === [3, 3]).to be(true)
  end

  it "matches each value using ===" do
    expect(MultiMatch.new(3, 3.14) === [Integer, Float]).to be(true)
  end

  it "matches are commutative" do
    expect(MultiMatch.new(3, 3.14) === MultiMatch.new(Integer, Float)).to be(true)
    expect(MultiMatch.new(Integer, Float) === MultiMatch.new(3, 3.14)).to be(true)
  end

  it "has TUPLE constant for match of array of two non nil values" do
    expect(MultiMatch::TUPLE === [3, 3]).to be(true)
  end

  it "has TRIPLE constant for match of array of two non nil values" do
    expect(MultiMatch::TRIPLE === [3, 3, 3]).to be(true)
  end

  it "considers length of array of values when matching" do
    expect(MultiMatch.new(not_nil, not_nil) === [6, 6, 6]).to be(false)
    expect(MultiMatch.new(not_nil, not_nil) === [6]).to be(false)
  end

end