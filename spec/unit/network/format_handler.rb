#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/format_handler'

class FormatTester
    extend Puppet::Network::FormatHandler

    # Not a supported format; missing the 'to'
    def self.from_nothing; end

    # Not a supported format; missing the 'from'
    def to_nowhere; end

    # A largely functional format.
    def self.from_good; end

    def to_good; end

    # A format that knows how to handle multiple instances specially.
    def self.from_mults; end

    def self.from_multiple_mults; end

    def self.to_multiple_mults; end

    def to_mults; end
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

    it "should be able to use a specific hook for converting into multiple instances" do
        FormatTester.expects(:from_multiple_mults).with("mydata")
        FormatTester.convert_from_multiple(:mults, "mydata")
    end

    it "should default to the normal conversion method when no special method is available" do
        FormatTester.expects(:from_good).with("mydata")
        FormatTester.convert_from_multiple(:good, "mydata")
    end

    it "should be able to use a specific hook for rendering multiple instances" do
        FormatTester.expects(:to_multiple_mults).with("mydata")
        FormatTester.render_multiple(:mults, "mydata")
    end

    it "should use the instance method if no multiple-render hook is available" do
        instances = mock 'instances'
        instances.expects(:to_good)
        FormatTester.render_multiple(:good, instances)
    end

    it "should be able to list supported formats" do
        FormatTester.should respond_to(:supported_formats)
    end

    it "should include all formats that include both the to_ and from_ methods in the list of supported formats" do
        FormatTester.supported_formats.sort.should == %w{good mults}.sort
    end

    it "should return the first format as the default format" do
        FormatTester.expects(:supported_formats).returns %w{one two}
        FormatTester.default_format.should == "one"
    end

    describe "when managing formats" do
        it "should have a method for defining a new format" do
            Puppet::Network::FormatHandler.should respond_to(:create)
        end

        it "should create a format instance when asked" do
            format = stub 'format', :name => "foo"
            Puppet::Network::Format.expects(:new).with(:foo).returns format
            Puppet::Network::FormatHandler.create(:foo)
        end

        it "should instance_eval any block provided when creating a format" do
            format = stub 'format', :name => :instance_eval
            format.expects(:yayness)
            Puppet::Network::Format.expects(:new).returns format
            Puppet::Network::FormatHandler.create(:instance_eval) do
                yayness
            end
        end

        it "should be able to retrieve a format by name" do
            format = Puppet::Network::FormatHandler.create(:by_name)
            Puppet::Network::FormatHandler.format(:by_name).should equal(format)
        end

        it "should be able to retrieve a format by mime type" do
            format = Puppet::Network::FormatHandler.create(:by_name, :mime => "foo/bar")
            Puppet::Network::FormatHandler.mime("foo/bar").should equal(format)
        end
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
            FormatTester.new.should respond_to(:render)
        end

        it "should fail if asked to convert to an unsupported format" do
            tester = FormatTester.new
            tester.expects(:support_format?).with(:nope).returns false
            lambda { tester.render(:nope) }.should raise_error(ArgumentError)
        end

        it "should call the format-specific converter when asked to convert to a given format" do
            tester = FormatTester.new
            tester.expects(:to_good)
            tester.render(:good)
        end

        it "should render to the default format if no format is provided when rendering" do
            FormatTester.expects(:default_format).returns "foo"
            tester = FormatTester.new
            tester.expects(:to_foo)
            tester.render
        end
    end
end
