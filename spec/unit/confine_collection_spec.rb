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
      test_class = double('test_class')
      expect(test_class).to receive(:new).with(%w{my values}).and_return(double('confine', :label= => nil))
      expect(Puppet::Confine).to receive(:test).with(:foo).and_return(test_class)

      Puppet::ConfineCollection.new("label").confine :foo => %w{my values}
    end

    it "should copy its label to the confine instance" do
      confine = double('confine')
      test_class = double('test_class')
      expect(test_class).to receive(:new).and_return(confine)
      expect(Puppet::Confine).to receive(:test).and_return(test_class)

      expect(confine).to receive(:label=).with("label")

      Puppet::ConfineCollection.new("label").confine :foo => %w{my values}
    end

    describe "and the test cannot be found" do
      it "should create a Facter test with the provided values and set the name to the test name" do
        confine = Puppet::Confine.test(:variable).new(%w{my values})
        expect(confine).to receive(:name=).with(:foo)
        expect(confine.class).to receive(:new).with(%w{my values}).and_return(confine)
        Puppet::ConfineCollection.new("label").confine(:foo => %w{my values})
      end
    end

    describe "and the 'for_binary' option was provided" do
      it "should mark the test as a binary confine" do
        confine = Puppet::Confine.test(:exists).new(:bar)
        expect(confine).to receive(:for_binary=).with(true)
        expect(Puppet::Confine.test(:exists)).to receive(:new).with(:bar).and_return(confine)
        Puppet::ConfineCollection.new("label").confine :exists => :bar, :for_binary => true
      end
    end
  end

  it "should be valid if no confines are present" do
    expect(Puppet::ConfineCollection.new("label")).to be_valid
  end

  it "should be valid if all confines pass" do
    c1 = double('c1', :valid? => true, :label= => nil)
    c2 = double('c2', :valid? => true, :label= => nil)

    expect(Puppet::Confine.test(:true)).to receive(:new).and_return(c1)
    expect(Puppet::Confine.test(:false)).to receive(:new).and_return(c2)

    confiner = Puppet::ConfineCollection.new("label")
    confiner.confine :true => :bar, :false => :bee

    expect(confiner).to be_valid
  end

  it "should not be valid if any confines fail" do
    c1 = double('c1', :valid? => true, :label= => nil)
    c2 = double('c2', :valid? => false, :label= => nil)

    expect(Puppet::Confine.test(:true)).to receive(:new).and_return(c1)
    expect(Puppet::Confine.test(:false)).to receive(:new).and_return(c2)

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
      expect(Puppet::Confine.test(:true)).to receive(:summarize).and_return(:tsumm)
      expect(Puppet::Confine.test(:false)).to receive(:summarize).and_return(:fsumm)

      expect(@confiner.summary).to eq({:true => :tsumm, :false => :fsumm})
    end

    it "should not include tests that return 0" do
      @confiner.confine :true => :bar, :false => :bee
      expect(Puppet::Confine.test(:true)).to receive(:summarize).and_return(0)
      expect(Puppet::Confine.test(:false)).to receive(:summarize).and_return(:fsumm)

      expect(@confiner.summary).to eq({:false => :fsumm})
    end

    it "should not include tests that return empty arrays" do
      @confiner.confine :true => :bar, :false => :bee
      expect(Puppet::Confine.test(:true)).to receive(:summarize).and_return([])
      expect(Puppet::Confine.test(:false)).to receive(:summarize).and_return(:fsumm)

      expect(@confiner.summary).to eq({:false => :fsumm})
    end

    it "should not include tests that return empty hashes" do
      @confiner.confine :true => :bar, :false => :bee
      expect(Puppet::Confine.test(:true)).to receive(:summarize).and_return({})
      expect(Puppet::Confine.test(:false)).to receive(:summarize).and_return(:fsumm)

      expect(@confiner.summary).to eq({:false => :fsumm})
    end
  end
end
