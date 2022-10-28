require 'spec_helper'

require 'puppet/confiner'

describe Puppet::Confiner do
  let(:coll) { Puppet::ConfineCollection.new('') }

  before do
    @object = Object.new
    @object.extend(Puppet::Confiner)
  end

  it "should have a method for defining confines" do
    expect(@object).to respond_to(:confine)
  end

  it "should have a method for returning its confine collection" do
    expect(@object).to respond_to(:confine_collection)
  end

  it "should have a method for testing suitability" do
    expect(@object).to respond_to(:suitable?)
  end

  it "should delegate its confine method to its confine collection" do
    allow(@object).to receive(:confine_collection).and_return(coll)
    expect(coll).to receive(:confine).with({:foo => :bar, :bee => :baz})
    @object.confine(:foo => :bar, :bee => :baz)
  end

  it "should create a new confine collection if one does not exist" do
    expect(Puppet::ConfineCollection).to receive(:new).with("mylabel").and_return("mycoll")
    expect(@object).to receive(:to_s).and_return("mylabel")
    expect(@object.confine_collection).to eq("mycoll")
  end

  it "should reuse the confine collection" do
    expect(@object.confine_collection).to equal(@object.confine_collection)
  end

  describe "when testing suitability" do
    before do
      allow(@object).to receive(:confine_collection).and_return(coll)
    end

    it "should return true if the confine collection is valid" do
      expect(coll).to receive(:valid?).and_return(true)
      expect(@object).to be_suitable
    end

    it "should return false if the confine collection is invalid" do
      expect(coll).to receive(:valid?).and_return(false)
      expect(@object).not_to be_suitable
    end

    it "should return the summary of the confine collection if a long result is asked for" do
      expect(coll).to receive(:summary).and_return("myresult")
      expect(@object.suitable?(false)).to eq("myresult")
    end
  end
end
