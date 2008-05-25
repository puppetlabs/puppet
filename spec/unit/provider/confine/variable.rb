#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/provider/confine/variable'

describe Puppet::Provider::Confine::Variable do
    it "should be named :variable" do
        Puppet::Provider::Confine::Variable.name.should == :variable
    end

    it "should require a value" do
        lambda { Puppet::Provider::Confine::Variable.new() }.should raise_error(ArgumentError)
    end

    it "should always convert values to an array" do
        Puppet::Provider::Confine::Variable.new("/some/file").values.should be_instance_of(Array)
    end

    it "should have an accessor for its name" do
        Puppet::Provider::Confine::Variable.new(:bar).should respond_to(:name)
    end

    describe "when testing values" do
        before do
            @confine = Puppet::Provider::Confine::Variable.new("foo")
            @confine.name = :myvar
        end

        it "should use the 'pass?' method to test validity" do
            @confine.expects(:pass?).with("foo")
            @confine.valid?
        end

        it "should use settings if the variable name is a valid setting" do
            Puppet.settings.expects(:valid?).with(:myvar).returns true
            Puppet.settings.expects(:value).with(:myvar).returns "foo"
            @confine.pass?("foo")
        end

        it "should use Facter if the variable name is not a valid setting" do
            Puppet.settings.expects(:valid?).with(:myvar).returns false
            Facter.expects(:value).with(:myvar).returns "foo"
            @confine.pass?("foo")
        end

        it "should return true if the value matches the facter value" do
            @confine.expects(:test_value).returns "foo"

            @confine.pass?("foo").should be_true
        end

        it "should return false if the value does not match the facter value" do
            @confine.expects(:test_value).returns "fee"

            @confine.pass?("foo").should be_false
        end

        it "should be case insensitive" do
            @confine.expects(:test_value).returns "FOO"

            @confine.pass?("foo").should be_true
        end

        it "should not care whether the value is a string or symbol" do
            @confine.expects(:test_value).returns "FOO"

            @confine.pass?(:foo).should be_true
        end

        it "should cache the facter value during testing" do
            Facter.expects(:value).once.returns("FOO")

            @confine.pass?(:foo)
            @confine.pass?(:foo)
        end

        it "should produce a message that the fact value is not correct" do
            @confine = Puppet::Provider::Confine::Variable.new(%w{bar bee})
            message = @confine.message("value")
            message.should be_include("facter")
            message.should be_include("bar,bee")
        end
    end

    describe "when summarizing multiple instances" do
        it "should return a hash of failing variables and their values" do
            c1 = stub '1', :valid? => false, :values => %w{one}, :fact => "uno"
            c2 = stub '2', :valid? => true,  :values => %w{two}, :fact => "dos"
            c3 = stub '3', :valid? => false, :values => %w{three}, :fact => "tres"

            Puppet::Provider::Confine::Variable.summarize([c1, c2, c3]).should == {"uno" => %w{one}, "tres" => %w{three}}
        end

        it "should combine the values of multiple confines with the same fact" do
            c1 = stub '1', :valid? => false, :values => %w{one}, :fact => "uno"
            c2 = stub '2', :valid? => false,  :values => %w{two}, :fact => "uno"

            Puppet::Provider::Confine::Variable.summarize([c1, c2]).should == {"uno" => %w{one two}}
        end
    end
end
