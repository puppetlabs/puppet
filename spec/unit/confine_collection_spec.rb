#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/confine_collection'

describe Puppet::ConfineCollection do
  it "should be able to add confines" do
    expect(Puppet::ConfineCollection.new("label")).to respond_to(:confine)
  end

  it "should require a label at initialization" do
    expect { Puppet::ConfineCollection.new }.to raise_error(ArgumentError)
  end

  it "should make its label available" do
    expect(Puppet::ConfineCollection.new("mylabel").label).to eq("mylabel")
  end

  describe "when creating confine instances" do
    it "should create an instance of the named test with the provided values" do
      test_class = mock 'test_class'
      test_class.expects(:new).with(%w{my values}).returns(stub('confine', :label= => nil))
      Puppet::Confine.expects(:test).with(:foo).returns test_class

      Puppet::ConfineCollection.new("label").confine :foo => %w{my values}
    end

    it "should copy its label to the confine instance" do
      confine = mock 'confine'
      test_class = mock 'test_class'
      test_class.expects(:new).returns confine
      Puppet::Confine.expects(:test).returns test_class

      confine.expects(:label=).with("label")

      Puppet::ConfineCollection.new("label").confine :foo => %w{my values}
    end

    describe "and the test cannot be found" do
      it "should create a Facter test with the provided values and set the name to the test name" do
        confine = Puppet::Confine.test(:variable).new(%w{my values})
        confine.expects(:name=).with(:foo)
        confine.class.expects(:new).with(%w{my values}).returns confine
        Puppet::ConfineCollection.new("label").confine(:foo => %w{my values})
      end
    end

    describe "and the 'for_binary' option was provided" do
      it "should mark the test as a binary confine" do
        confine = Puppet::Confine.test(:exists).new(:bar)
        confine.expects(:for_binary=).with true
        Puppet::Confine.test(:exists).expects(:new).with(:bar).returns confine
        Puppet::ConfineCollection.new("label").confine :exists => :bar, :for_binary => true
      end
    end
  end

  it "should be valid if no confines are present" do
    expect(Puppet::ConfineCollection.new("label")).to be_valid
  end

  it "should be valid if all confines pass" do
    c1 = stub 'c1', :valid? => true, :label= => nil
    c2 = stub 'c2', :valid? => true, :label= => nil

    Puppet::Confine.test(:true).expects(:new).returns(c1)
    Puppet::Confine.test(:false).expects(:new).returns(c2)

    confiner = Puppet::ConfineCollection.new("label")
    confiner.confine :true => :bar, :false => :bee

    expect(confiner).to be_valid
  end

  it "should not be valid if any confines fail" do
    c1 = stub 'c1', :valid? => true, :label= => nil
    c2 = stub 'c2', :valid? => false, :label= => nil

    Puppet::Confine.test(:true).expects(:new).returns(c1)
    Puppet::Confine.test(:false).expects(:new).returns(c2)

    confiner = Puppet::ConfineCollection.new("label")
    confiner.confine :true => :bar, :false => :bee

    expect(confiner).not_to be_valid
  end

  describe "when providing a summary" do
    before do
      @confiner = Puppet::ConfineCollection.new("label")
    end

    it "should return a hash" do
      expect(@confiner.summary).to be_instance_of(Hash)
    end

    it "should return an empty hash if the confiner is valid" do
      expect(@confiner.summary).to eq({})
    end

    it "should add each test type's summary to the hash" do
      @confiner.confine :true => :bar, :false => :bee
      Puppet::Confine.test(:true).expects(:summarize).returns :tsumm
      Puppet::Confine.test(:false).expects(:summarize).returns :fsumm

      expect(@confiner.summary).to eq({:true => :tsumm, :false => :fsumm})
    end

    it "should not include tests that return 0" do
      @confiner.confine :true => :bar, :false => :bee
      Puppet::Confine.test(:true).expects(:summarize).returns 0
      Puppet::Confine.test(:false).expects(:summarize).returns :fsumm

      expect(@confiner.summary).to eq({:false => :fsumm})
    end

    it "should not include tests that return empty arrays" do
      @confiner.confine :true => :bar, :false => :bee
      Puppet::Confine.test(:true).expects(:summarize).returns []
      Puppet::Confine.test(:false).expects(:summarize).returns :fsumm

      expect(@confiner.summary).to eq({:false => :fsumm})
    end

    it "should not include tests that return empty hashes" do
      @confiner.confine :true => :bar, :false => :bee
      Puppet::Confine.test(:true).expects(:summarize).returns({})
      Puppet::Confine.test(:false).expects(:summarize).returns :fsumm

      expect(@confiner.summary).to eq({:false => :fsumm})
    end
  end
end
