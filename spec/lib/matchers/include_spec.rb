require 'spec_helper'
require 'matchers/include'

describe "include matchers" do
  include Matchers::Include

  context :include_in_any_order do
    it "matches an empty list" do
      expect([]).to include_in_any_order()
    end

    it "matches a list with a single element" do
      expect([1]).to include_in_any_order(eq(1))
    end

    it "does not match when an expected element is missing" do
      expect([1]).to_not include_in_any_order(eq(2))
    end

    it "matches a list with 2 elements in a different order from the expectation" do
      expect([1, 2]).to include_in_any_order(eq(2), eq(1))
    end

    it "does not match when there are more than just the expected elements" do
      expect([1, 2]).to_not include_in_any_order(eq(1))
    end

    it "matches multiple, equal elements when there are multiple, equal exepectations" do
      expect([1, 1]).to include_in_any_order(eq(1), eq(1))
    end
  end
end
