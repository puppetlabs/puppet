#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/network/format_handler'
require 'puppet/network/format_support'

class FormatTester
  include Puppet::Network::FormatSupport
end

describe Puppet::Network::FormatHandler do
  before(:each) do
    @saved_formats = Puppet::Network::FormatHandler.instance_variable_get(:@formats).dup
    Puppet::Network::FormatHandler.instance_variable_set(:@formats, {})
  end

  after(:each) do
    Puppet::Network::FormatHandler.instance_variable_set(:@formats, @saved_formats)
  end

  describe "when listing formats" do
    before(:each) do
      one = Puppet::Network::FormatHandler.create(:one, :weight => 1)
      one.stubs(:supported?).returns(true)
      two = Puppet::Network::FormatHandler.create(:two, :weight => 6)
      two.stubs(:supported?).returns(true)
      three = Puppet::Network::FormatHandler.create(:three, :weight => 2)
      three.stubs(:supported?).returns(true)
      four = Puppet::Network::FormatHandler.create(:four, :weight => 8)
      four.stubs(:supported?).returns(false)
    end

    it "should return all supported formats in decreasing order of weight" do
      expect(FormatTester.supported_formats).to eq([:two, :three, :one])
    end
  end

  it "should return the first format as the default format" do
    FormatTester.expects(:supported_formats).returns [:one, :two]
    expect(FormatTester.default_format).to eq(:one)
  end

  describe "with a preferred serialization format setting" do
    before do
      one = Puppet::Network::FormatHandler.create(:one, :weight => 1)
      one.stubs(:supported?).returns(true)
      two = Puppet::Network::FormatHandler.create(:two, :weight => 6)
      two.stubs(:supported?).returns(true)
    end

    describe "that is supported" do
      before do
        Puppet[:preferred_serialization_format] = :one
      end

      it "should return the preferred serialization format first" do
        expect(FormatTester.supported_formats).to eq([:one, :two])
      end
    end

    describe "that is not supported" do
      before do
        Puppet[:preferred_serialization_format] = :unsupported
      end

      it "should return the default format first" do
        expect(FormatTester.supported_formats).to eq([:two, :one])
      end

      it "should log a debug message" do
        Puppet.expects(:debug).with("Value of 'preferred_serialization_format' (unsupported) is invalid for FormatTester, using default (two)")
        Puppet.expects(:debug).with("FormatTester supports formats: two one")
        FormatTester.supported_formats
      end
    end
  end

  describe "when using formats" do
    let(:format) { Puppet::Network::FormatHandler.create(:my_format, :mime => "text/myformat") }

    it "should use the Format to determine whether a given format is supported" do
      format.expects(:supported?).with(FormatTester)
      FormatTester.support_format?(:my_format)
    end

    it "should call the format-specific converter when asked to convert from a given format" do
      format.expects(:intern).with(FormatTester, "mydata")
      FormatTester.convert_from(:my_format, "mydata")
    end

    it "should call the format-specific converter when asked to convert from a given format by mime-type" do
      format.expects(:intern).with(FormatTester, "mydata")
      FormatTester.convert_from("text/myformat", "mydata")
    end

    it "should call the format-specific converter when asked to convert from a given format by format instance" do
      format.expects(:intern).with(FormatTester, "mydata")
      FormatTester.convert_from(format, "mydata")
    end

    it "should raise a FormatError when an exception is encountered when converting from a format" do
      format.expects(:intern).with(FormatTester, "mydata").raises "foo"
      expect do
        FormatTester.convert_from(:my_format, "mydata")
      end.to raise_error(
        Puppet::Network::FormatHandler::FormatError,
        'Could not intern from my_format: foo'
      )
    end

    it "should be able to use a specific hook for converting into multiple instances" do
      format.expects(:intern_multiple).with(FormatTester, "mydata")

      FormatTester.convert_from_multiple(:my_format, "mydata")
    end

    it "should raise a FormatError when an exception is encountered when converting multiple items from a format" do
      format.expects(:intern_multiple).with(FormatTester, "mydata").raises "foo"
      expect do
        FormatTester.convert_from_multiple(:my_format, "mydata")
      end.to raise_error(Puppet::Network::FormatHandler::FormatError, 'Could not intern_multiple from my_format: foo')
    end

    it "should be able to use a specific hook for rendering multiple instances" do
      format.expects(:render_multiple).with("mydata")

      FormatTester.render_multiple(:my_format, "mydata")
    end

    it "should raise a FormatError when an exception is encountered when rendering multiple items into a format" do
      format.expects(:render_multiple).with("mydata").raises "foo"
      expect do
        FormatTester.render_multiple(:my_format, "mydata")
      end.to raise_error(Puppet::Network::FormatHandler::FormatError, 'Could not render_multiple to my_format: foo')
    end
  end

  describe "when an instance" do
    let(:format) { Puppet::Network::FormatHandler.create(:foo, :mime => "text/foo") }

    it "should list as supported a format that reports itself supported" do
      format.expects(:supported?).returns true
      expect(FormatTester.new.support_format?(:foo)).to be_truthy
    end

    it "should raise a FormatError when a rendering error is encountered" do
      tester = FormatTester.new
      format.expects(:render).with(tester).raises "eh"

      expect do
        tester.render(:foo)
      end.to raise_error(Puppet::Network::FormatHandler::FormatError, 'Could not render to foo: eh')
    end

    it "should call the format-specific converter when asked to convert to a given format" do
      tester = FormatTester.new
      format.expects(:render).with(tester).returns "foo"

      expect(tester.render(:foo)).to eq("foo")
    end

    it "should call the format-specific converter when asked to convert to a given format by mime-type" do
      tester = FormatTester.new
      format.expects(:render).with(tester).returns "foo"

      expect(tester.render("text/foo")).to eq("foo")
    end

    it "should call the format converter when asked to convert to a given format instance" do
      tester = FormatTester.new
      format.expects(:render).with(tester).returns "foo"

      expect(tester.render(format)).to eq("foo")
    end

    it "should render to the default format if no format is provided when rendering" do
      FormatTester.expects(:default_format).returns :foo
      tester = FormatTester.new

      format.expects(:render).with(tester)
      tester.render
    end

    it "should call the format-specific converter when asked for the mime-type of a given format" do
      tester = FormatTester.new
      format.expects(:mime).returns "text/foo"

      expect(tester.mime(:foo)).to eq("text/foo")
    end

    it "should return the default format mime-type if no format is provided" do
      FormatTester.expects(:default_format).returns :foo
      tester = FormatTester.new

      format.expects(:mime).returns "text/foo"
      expect(tester.mime).to eq("text/foo")
    end
  end
end
