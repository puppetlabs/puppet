require 'spec_helper'
require 'matchers/include_in_order'

describe "Matching whether elements are included in order" do
  context "an empty array" do
    it "is included in an empty array" do
      expect([]).to include_in_order()
    end

    it "is included in a non-empty array" do
      expect([1]).to include_in_order()
    end
  end

  it "[1,2,3] is included in [0,1,2,3,4]" do
    expect([0,1,2,3,4]).to include_in_order(1,2,3)
  end

  it "[2,1] is not included in order in [1,2]" do
    expect([1,2]).not_to include_in_order(2,1)
  end

  it "[2,4,6] is included in order in [1,2,3,4,5,6]" do
    expect([1,2,3,4,5,6]).to include_in_order(2,4,6)
  end

  it "overlapping ordered array is not included" do
    expect([1,2,3]).not_to include_in_order(2,3,4)
  end
end
