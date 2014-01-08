#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/confine/variable'

describe Puppet::Confine::Variable do
  it "should be named :variable" do
    Puppet::Confine::Variable.name.should == :variable
  end

  it "should require a value" do
    lambda { Puppet::Confine::Variable.new }.should raise_error(ArgumentError)
  end

  it "should always convert values to an array" do
    Puppet::Confine::Variable.new("/some/file").values.should be_instance_of(Array)
  end

  it "should have an accessor for its name" do
    Puppet::Confine::Variable.new(:bar).should respond_to(:name)
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

      @confine.should be_valid
    end

    it "should return false if the value does not match the facter value" do
      @confine.expects(:test_value).returns "fee"

      @confine.should_not be_valid
    end

    it "should be case insensitive" do
      @confine.expects(:test_value).returns "FOO"

      @confine.should be_valid
    end

    it "should not care whether the value is a string or symbol" do
      @confine.expects(:test_value).returns "FOO"

      @confine.should be_valid
    end

    it "should produce a message that the fact value is not correct" do
      @confine = Puppet::Confine::Variable.new(%w{bar bee})
      @confine.name = "eh"
      message = @confine.message("value")
      message.should be_include("facter")
      message.should be_include("bar,bee")
    end

    it "should be valid if the test value matches any of the provided values" do
      @confine = Puppet::Confine::Variable.new(%w{bar bee})
      @confine.expects(:test_value).returns "bee"
      @confine.should be_valid
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

      Puppet::Confine::Variable.summarize([c1, c2, c3]).should == {"uno" => %w{one}, "tres" => %w{three}}
    end

    it "should combine the values of multiple confines with the same fact" do
      c1 = Puppet::Confine::Variable.new("one")
      c1.name = "uno"
      c1.expects(:valid?).returns false
      c2 = Puppet::Confine::Variable.new("two")
      c2.name = "uno"
      c2.expects(:valid?).returns false

      Puppet::Confine::Variable.summarize([c1, c2]).should == {"uno" => %w{one two}}
    end
  end
end
