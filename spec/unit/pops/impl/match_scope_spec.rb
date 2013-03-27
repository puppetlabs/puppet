require 'spec_helper'
require 'puppet/pops/impl/match_scope'

MatchScope = Puppet::Pops::Impl::MatchScope

describe Puppet::Pops::Impl::MatchScope do

  describe "A match scope without match data" do
    it "should produce entries for all numeric variables" do
      scope = MatchScope.new
      result = (0..99).collect { |n| scope.get_entry(n) }
      result.count.should == 100
      result = result.compact
      result.count.should == 100
    end
    it "should produce entries with nil values for all numeric variables" do
      scope = MatchScope.new
      result = (0..99).collect { |n| scope[n].value }
      result.count.should == 100
      result = result.compact
      result.count.should == 0
    end
    it "should have entries without origin" do
      scope = MatchScope.new
      scope[0].origin.should == nil
    end
  end

  describe "A match scope with one match" do
    it "should produce a single entry with the expected match" do
      scope = MatchScope.new(/.*/.match("monkey likes banana"))
      scope.get_entry(0).value.should == "monkey likes banana"
      scope.get_entry(1).value.should == nil
    end
  end

  describe "A match scope with more than one match" do
    it "should produce an entry for each group" do
      scope = MatchScope.new(/(monkey)\s(likes)\s(banana)/.match("monkey likes banana"))
      scope[0].value.should == "monkey likes banana"
      scope[1].value.should == "monkey"
      scope[2].value.should == "likes"
      scope[3].value.should == "banana"
      scope[4].value.should == nil
    end

    it "should produce the same result on [] as on get_entry" do
      scope = MatchScope.new(/(monkey)\s(likes)\s(banana)/.match("monkey likes banana"))
      scope[0].value.should == scope.get_entry(0).value
      scope[1].value.should == scope.get_entry(1).value
      # skipping 2..3
      scope[4].value.should == scope.get_entry(4).value
    end
  end
end