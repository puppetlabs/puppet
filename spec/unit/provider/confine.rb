#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/provider/confine'

describe Puppet::Provider::Confine do
    it "should require a test" do
        lambda { Puppet::Provider::Confine.new }.should raise_error(ArgumentError)
    end

    it "should require a value" do
        lambda { Puppet::Provider::Confine.new(:exists) }.should raise_error(ArgumentError)
    end

    it "should have a test" do
        Puppet::Provider::Confine.new(:exists, "/some/file").test.should == :exists
    end

    it "should always convert values to an array" do
        Puppet::Provider::Confine.new(:exists, "/some/file").values.should be_instance_of(Array)
    end

    it "should have an accessor for its fact" do
        Puppet::Provider::Confine.new(:foo, :bar).should respond_to(:fact)
    end

    it "should be possible to mark the confine as a binary test" do
        Puppet::Provider::Confine.new(:foo, :bar).should respond_to(:for_binary=)
    end

    it "should have a boolean method to indicate it's a binary confine" do
        Puppet::Provider::Confine.new(:foo, :bar).should respond_to(:for_binary?)
    end

    it "should indicate it's a boolean confine if it has been marked that way" do
        confine = Puppet::Provider::Confine.new(:foo, :bar)
        confine.for_binary = true
        confine.should be_for_binary
    end

    it "should have a method for returning a binary's path" do
        Puppet::Provider::Confine.new(:foo, :bar).private_methods.should be_include("binary")
    end

    describe "when testing values" do
        before { @confine = Puppet::Provider::Confine.new("eh", "foo") }

        describe "and the test is 'false'" do
            it "should use the 'false?' method to test validity" do
                @confine = Puppet::Provider::Confine.new(:false, "foo")
                @confine.expects(:false?).with("foo")
                @confine.valid?
            end

            it "should return true if the value is false" do
                @confine.false?(false).should be_true
            end

            it "should return false if the value is not false" do
                @confine.false?("else").should be_false
            end

            it "should log that a value is false" do
                @confine = Puppet::Provider::Confine.new(:false, "foo")
                Puppet.expects(:debug).with { |l| l.include?("false") }
                @confine.valid?
            end
        end

        describe "and the test is 'true'" do
            it "should use the 'true?' method to test validity" do
                @confine = Puppet::Provider::Confine.new(:true, "foo")
                @confine.expects(:true?).with("foo")
                @confine.valid?
            end

            it "should return true if the value is not false" do
                @confine.true?("else").should be_true
            end

            it "should return false if the value is false" do
                @confine.true?(nil).should be_false
            end
        end

        describe "and the test is 'exists'" do
            it "should use the 'exists?' method to test validity" do
                @confine = Puppet::Provider::Confine.new(:exists, "foo")
                @confine.expects(:exists?).with("foo")
                @confine.valid?
            end

            it "should return false if the value is false" do
                @confine.exists?(false).should be_false
            end

            it "should return false if the value does not point to a file" do
                FileTest.expects(:exist?).with("/my/file").returns false
                @confine.exists?("/my/file").should be_false
            end

            it "should return true if the value points to a file" do
                FileTest.expects(:exist?).with("/my/file").returns true
                @confine.exists?("/my/file").should be_true
            end

            it "should log that a value is true" do
                @confine = Puppet::Provider::Confine.new(:true, nil)
                Puppet.expects(:debug).with { |l| l.include?("true") }
                @confine.valid?
            end

            describe "and the confine is for binaries" do
                before { @confine.stubs(:for_binary).returns true }
                it "should use its 'binary' method to look up the full path of the file" do
                    @confine.expects(:binary).returns nil
                    @confine.exists?("/my/file")
                end

                it "should return false if no binary can be found" do
                    @confine.expects(:binary).with("/my/file").returns nil
                    @confine.exists?("/my/file").should be_false
                end

                it "should return true if the binary can be found and the file exists" do
                    @confine.expects(:binary).with("/my/file").returns "/my/file"
                    FileTest.expects(:exist?).with("/my/file").returns true
                    @confine.exists?("/my/file").should be_true
                end

                it "should return false if the binary can be found but the file does not exist" do
                    @confine.expects(:binary).with("/my/file").returns "/my/file"
                    FileTest.expects(:exist?).with("/my/file").returns true
                    @confine.exists?("/my/file").should be_true
                end
            end
        end

        describe "and the test is not 'true', 'false', or 'exists'" do
            it "should use the 'match?' method to test validity" do
                @confine = Puppet::Provider::Confine.new("yay", "foo")
                @confine.expects(:match?).with("foo")
                @confine.valid?
            end

            it "should return true if the value matches the facter value" do
                Facter.expects(:value).returns("foo")

                @confine.match?("foo").should be_true
            end

            it "should return false if the value does not match the facter value" do
                Facter.expects(:value).returns("boo")

                @confine.match?("foo").should be_false
            end

            it "should be case insensitive" do
                Facter.expects(:value).returns("FOO")

                @confine.match?("foo").should be_true
            end

            it "should not care whether the value is a string or symbol" do
                Facter.expects(:value).returns("FOO")

                @confine.match?(:foo).should be_true
            end

            it "should cache the fact during testing" do
                Facter.expects(:value).once.returns("FOO")

                @confine.match?(:foo)
                @confine.match?(:foo)
            end

            it "should log that the fact value is not correct" do
                @confine = Puppet::Provider::Confine.new("foo", ["bar", "bee"])
                Facter.expects(:value).with("foo").returns "yayness"
                Puppet.expects(:debug).with { |l| l.include?("facter") and l.include?("bar,bee") }
                @confine.valid?
            end
        end
    end

    describe "when testing all values" do
        before { @confine = Puppet::Provider::Confine.new(:true, %w{a b c}) }

        it "should be invalid if any values fail" do
            @confine.stubs(:true?).returns true
            @confine.expects(:true?).with("b").returns false
            @confine.should_not be_valid
        end

        it "should be valid if all values pass" do
            @confine.stubs(:true?).returns true
            @confine.should be_valid
        end

        it "should short-cut at the first failing value" do
            @confine.expects(:true?).once.returns false
            @confine.valid?
        end

        it "should remove the cached facter value" do
            @confine = Puppet::Provider::Confine.new(:foo, :bar)
            Facter.expects(:value).with(:foo).times(2).returns "eh"
            @confine.valid?
            @confine.valid?
        end
    end

    describe "when testing the result of the values" do
        before { @confine = Puppet::Provider::Confine.new(:true, %w{a b c d}) }

        it "should return an array with the result of the test for each value" do
            @confine.stubs(:true?).returns true
            @confine.expects(:true?).with("b").returns false
            @confine.expects(:true?).with("d").returns false

            @confine.result.should == [true, false, true, false]
        end
    end
end
