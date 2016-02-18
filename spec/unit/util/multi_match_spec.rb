#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/util/multi_match'

describe "The Puppet::Util::MultiMatch" do
  let(:not_nil) { Puppet::Util::MultiMatch::NOT_NIL }
  let(:mm) { Puppet::Util::MultiMatch }

  it "matches against not nil" do
    expect(not_nil === 3).to be(true)
  end

  it "matches against multiple values" do
    expect(mm.new(not_nil, not_nil) === [3, 3]).to be(true)
  end

  it "matches each value using ===" do
    expect(mm.new(3, 3.14) === [Integer, Float]).to be(true)
  end

  it "matches are commutative" do
    expect(mm.new(3, 3.14) === mm.new(Integer, Float)).to be(true)
    expect(mm.new(Integer, Float) === mm.new(3, 3.14)).to be(true)
  end

  it "has TUPLE constant for match of array of two non nil values" do
    expect(mm::TUPLE === [3, 3]).to be(true)
  end

  it "has TRIPLE constant for match of array of two non nil values" do
    expect(mm::TRIPLE === [3, 3, 3]).to be(true)
  end

  it "considers length of array of values when matching" do
    expect(mm.new(not_nil, not_nil) === [6, 6, 6]).to be(false)
    expect(mm.new(not_nil, not_nil) === [6]).to be(false)
  end

end
