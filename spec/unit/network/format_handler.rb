#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/format_handler'

class FormatTester
    extend Puppet::Network::FormatHandler

    # Not a supported format; missing the 'to'
    def self.from_nothing
    end

    # Not a supported format; missing the 'from'
    def to_nowhere
    end

    def self.from_good
    end

    def to_good
    end
end

describe Puppet::Network::FormatHandler do
    it "should be able to test whether a format is supported" do
        FormatTester.should respond_to(:support_format?)
    end

    it "should consider the format supported if it can convert from an instance to the format and from the format to an instance" do
        FormatTester.should be_support_format(:good)
    end

    it "should not consider the format supported unless it can convert the instance to the specified format" do
        FormatTester.should_not be_support_format(:nothing)
    end

    it "should not consider the format supported unless it can convert from the format to an instance" do
        FormatTester.should_not be_support_format(:nowhere)
    end

    it "should be able to convert from a given format" do
        FormatTester.should respond_to(:convert_from)
    end

    it "should fail if asked to convert from an unsupported format" do
        FormatTester.expects(:support_format?).with(:nope).returns false
        lambda { FormatTester.convert_from(:nope, "mydata") }.should raise_error(ArgumentError)
    end

    it "should call the format-specific converter when asked to convert from a given format" do
        FormatTester.expects(:from_good).with("mydata")
        FormatTester.convert_from(:good, "mydata")
    end

    it "should be able to list supported formats" do
        FormatTester.should respond_to(:supported_formats)
    end

    it "should include all formats that include both the to_ and from_ methods in the list of supported formats" do
        FormatTester.supported_formats.should == %w{good}
    end

    describe "when an instance" do
        it "should be able to test whether a format is supported" do
            FormatTester.new.should respond_to(:support_format?)
        end

        it "should consider the format supported if it can convert from an instance to the format and from the format to an instance" do
            FormatTester.new.should be_support_format(:good)
        end

        it "should not consider the format supported unless it can convert from an instance to the format and from the format to an instance" do
            FormatTester.new.should_not be_support_format(:nope)
        end

        it "should be able to convert to a given format" do
            FormatTester.new.should respond_to(:render_to)
        end

        it "should fail if asked to convert to an unsupported format" do
            tester = FormatTester.new
            tester.expects(:support_format?).with(:nope).returns false
            lambda { tester.render_to(:nope) }.should raise_error(ArgumentError)
        end

        it "should call the format-specific converter when asked to convert to a given format" do
            tester = FormatTester.new
            tester.expects(:to_good)
            tester.render_to(:good)
        end
    end
end
