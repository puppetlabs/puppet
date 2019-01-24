require 'spec_helper'

require 'puppet/confine/true'

describe Puppet::Confine::True do
  it "should be named :true" do
    expect(Puppet::Confine::True.name).to eq(:true)
  end

  it "should require a value" do
    expect { Puppet::Confine::True.new }.to raise_error(ArgumentError)
  end

  describe "when passing in a lambda as a value for lazy evaluation" do
    it "should accept it" do
      confine = Puppet::Confine::True.new(lambda { true })
      expect(confine.values).to eql([true])
    end

    describe "when enforcing cache-positive behavior" do
      def cached_value_of(confine)
        confine.instance_variable_get(:@cached_value)
      end

      it "should cache a true value" do
        confine = Puppet::Confine::True.new(lambda { true })
        confine.values

        expect(cached_value_of(confine)).to eql([true])
      end

      it "should not cache a false value" do
        confine = Puppet::Confine::True.new(lambda { false })
        confine.values

        expect(cached_value_of(confine)).to be_nil
      end
    end
  end

  describe "when testing values" do
    before do
      @confine = Puppet::Confine::True.new("foo")
      @confine.label = "eh"
    end

    it "should use the 'pass?' method to test validity" do
      expect(@confine).to receive(:pass?).with("foo")
      @confine.valid?
    end

    it "should return true if the value is not false" do
      expect(@confine.pass?("else")).to be_truthy
    end

    it "should return false if the value is false" do
      expect(@confine.pass?(nil)).to be_falsey
    end

    it "should produce the message that a value is false" do
      expect(@confine.message("eh")).to be_include("false")
    end
  end

  it "should produce the number of false values when asked for a summary" do
    @confine = Puppet::Confine::True.new %w{one two three four}
    expect(@confine).to receive(:pass?).exactly(4).times.and_return(true, false, true, false)
    expect(@confine.summary).to eq(2)
  end

  it "should summarize multiple instances by summing their summaries" do
    c1 = double('1', :summary => 1)
    c2 = double('2', :summary => 2)
    c3 = double('3', :summary => 3)

    expect(Puppet::Confine::True.summarize([c1, c2, c3])).to eq(6)
  end
end
