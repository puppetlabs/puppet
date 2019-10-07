require 'spec_helper'

require 'puppet/confine/false'

describe Puppet::Confine::False do
  it "should be named :false" do
    expect(Puppet::Confine::False.name).to eq(:false)
  end

  it "should require a value" do
    expect { Puppet::Confine.new }.to raise_error(ArgumentError)
  end

  describe "when passing in a lambda as a value for lazy evaluation" do
    it "should accept it" do
      confine = Puppet::Confine::False.new(lambda { false })
      expect(confine.values).to eql([false])
    end

    describe "when enforcing cache-positive behavior" do
      def cached_value_of(confine)
        confine.instance_variable_get(:@cached_value)
      end

      it "should cache a false value" do
        confine = Puppet::Confine::False.new(lambda { false })
        confine.values

        expect(cached_value_of(confine)).to eql([false])
      end

      it "should not cache a true value" do
        confine = Puppet::Confine::False.new(lambda { true })
        confine.values

        expect(cached_value_of(confine)).to be_nil
      end
    end
  end

  describe "when testing values" do
    before { @confine = Puppet::Confine::False.new("foo") }

    it "should use the 'pass?' method to test validity" do
      @confine = Puppet::Confine::False.new("foo")
      @confine.label = "eh"
      expect(@confine).to receive(:pass?).with("foo")
      @confine.valid?
    end

    it "should return true if the value is false" do
      expect(@confine.pass?(false)).to be_truthy
    end

    it "should return false if the value is not false" do
      expect(@confine.pass?("else")).to be_falsey
    end

    it "should produce a message that a value is true" do
      @confine = Puppet::Confine::False.new("foo")
      expect(@confine.message("eh")).to be_include("true")
    end
  end

  it "should be able to produce a summary with the number of incorrectly true values" do
    confine = Puppet::Confine::False.new %w{one two three four}
    expect(confine).to receive(:pass?).exactly(4).times.and_return(true, false, true, false)
    expect(confine.summary).to eq(2)
  end

  it "should summarize multiple instances by summing their summaries" do
    c1 = double('1', :summary => 1)
    c2 = double('2', :summary => 2)
    c3 = double('3', :summary => 3)

    expect(Puppet::Confine::False.summarize([c1, c2, c3])).to eq(6)
  end
end
