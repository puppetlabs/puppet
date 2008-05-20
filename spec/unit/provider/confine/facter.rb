#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/provider/confine/facter'

describe Puppet::Provider::Confine::Facter::Facter do
    it "should be named :facter" do
        Puppet::Provider::Confine::Facter.name.should == :facter
    end

    it "should require a value" do
        lambda { Puppet::Provider::Confine::Facter.new() }.should raise_error(ArgumentError)
    end

    it "should always convert values to an array" do
        Puppet::Provider::Confine::Facter.new("/some/file").values.should be_instance_of(Array)
    end

    it "should have an accessor for its fact" do
        Puppet::Provider::Confine::Facter.new(:bar).should respond_to(:fact)
    end

    describe "when testing values" do
        before { @confine = Puppet::Provider::Confine::Facter.new("foo") }
        it "should use the 'pass?' method to test validity" do
            @confine.expects(:pass?).with("foo")
            @confine.valid?
        end

        it "should return true if the value matches the facter value" do
            Facter.expects(:value).returns("foo")

            @confine.pass?("foo").should be_true
        end

        it "should return false if the value does not match the facter value" do
            Facter.expects(:value).returns("boo")

            @confine.pass?("foo").should be_false
        end

        it "should be case insensitive" do
            Facter.expects(:value).returns("FOO")

            @confine.pass?("foo").should be_true
        end

        it "should not care whether the value is a string or symbol" do
            Facter.expects(:value).returns("FOO")

            @confine.pass?(:foo).should be_true
        end

        it "should cache the fact during testing" do
            Facter.expects(:value).once.returns("FOO")

            @confine.pass?(:foo)
            @confine.pass?(:foo)
        end

        it "should produce a message that the fact value is not correct" do
            @confine = Puppet::Provider::Confine::Facter.new(%w{bar bee})
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

            Puppet::Provider::Confine::Facter.summarize([c1, c2, c3]).should == {"uno" => %w{one}, "tres" => %w{three}}
        end

        it "should combine the values of multiple confines with the same fact" do
            c1 = stub '1', :valid? => false, :values => %w{one}, :fact => "uno"
            c2 = stub '2', :valid? => false,  :values => %w{two}, :fact => "uno"

            Puppet::Provider::Confine::Facter.summarize([c1, c2]).should == {"uno" => %w{one two}}
        end
    end
end
