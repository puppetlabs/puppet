#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/confine/variable'

describe Puppet::Confine::Variable do
  it "should be named :variable" do
    expect(Puppet::Confine::Variable.name).to eq(:variable)
  end

  it "should require a value" do
    expect { Puppet::Confine::Variable.new }.to raise_error(ArgumentError)
  end

  it "should always convert values to an array" do
    expect(Puppet::Confine::Variable.new("/some/file").values).to be_instance_of(Array)
  end

  it "should have an accessor for its name" do
    expect(Puppet::Confine::Variable.new(:bar)).to respond_to(:name)
  end

  describe "when testing values" do
    before do
      @confine = Puppet::Confine::Variable.new("foo")
      @confine.name = :myvar
    end

    it "should use settings if the variable name is a valid setting" do
      Puppet.settings.expects(:valid?).with(:myvar).returns true
      Puppet.settings.expects(:value).with(:myvar).returns "foo"
      @confine.valid?
    end

    it "should use Facter if the variable name is not a valid setting" do
      Puppet.settings.expects(:valid?).with(:myvar).returns false
      Facter.expects(:value).with(:myvar).returns "foo"
      @confine.valid?
    end

    it "should be valid if the value matches the facter value" do
      @confine.expects(:test_value).returns "foo"

      expect(@confine).to be_valid
    end

    it "should return false if the value does not match the facter value" do
      @confine.expects(:test_value).returns "fee"

      expect(@confine).not_to be_valid
    end

    it "should be case insensitive" do
      @confine.expects(:test_value).returns "FOO"

      expect(@confine).to be_valid
    end

    it "should not care whether the value is a string or symbol" do
      @confine.expects(:test_value).returns "FOO"

      expect(@confine).to be_valid
    end

    it "should produce a message that the fact value is not correct" do
      @confine = Puppet::Confine::Variable.new(%w{bar bee})
      @confine.name = "eh"
      message = @confine.message("value")
      expect(message).to be_include("facter")
      expect(message).to be_include("bar,bee")
    end

    it "should be valid if the test value matches any of the provided values" do
      @confine = Puppet::Confine::Variable.new(%w{bar bee})
      @confine.expects(:test_value).returns "bee"
      expect(@confine).to be_valid
    end
  end

  describe "when summarizing multiple instances" do
    it "should return a hash of failing variables and their values" do
      c1 = Puppet::Confine::Variable.new("one")
      c1.name = "uno"
      c1.expects(:valid?).returns false
      c2 = Puppet::Confine::Variable.new("two")
      c2.name = "dos"
      c2.expects(:valid?).returns true
      c3 = Puppet::Confine::Variable.new("three")
      c3.name = "tres"
      c3.expects(:valid?).returns false

      expect(Puppet::Confine::Variable.summarize([c1, c2, c3])).to eq({"uno" => %w{one}, "tres" => %w{three}})
    end

    it "should combine the values of multiple confines with the same fact" do
      c1 = Puppet::Confine::Variable.new("one")
      c1.name = "uno"
      c1.expects(:valid?).returns false
      c2 = Puppet::Confine::Variable.new("two")
      c2.name = "uno"
      c2.expects(:valid?).returns false

      expect(Puppet::Confine::Variable.summarize([c1, c2])).to eq({"uno" => %w{one two}})
    end
  end
end
