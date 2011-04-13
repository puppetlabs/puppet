#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/network/format_handler'

class FormatTester
  extend Puppet::Network::FormatHandler
end

describe Puppet::Network::FormatHandler do
  after do
    formats = Puppet::Network::FormatHandler.instance_variable_get("@formats")
    formats.each do |name, format|
      formats.delete(name) unless format.is_a?(Puppet::Network::Format)
    end
  end

  it "should be able to list supported formats" do
    FormatTester.should respond_to(:supported_formats)
  end

  it "should include all supported formats" do
    one = stub 'supported', :supported? => true, :name => :one, :weight => 1
    two = stub 'supported', :supported? => false, :name => :two, :weight => 1
    three = stub 'supported', :supported? => true, :name => :three, :weight => 1
    four = stub 'supported', :supported? => false, :name => :four, :weight => 1
    Puppet::Network::FormatHandler.stubs(:formats).returns [:one, :two, :three, :four]
    Puppet::Network::FormatHandler.stubs(:format).with(:one).returns one
    Puppet::Network::FormatHandler.stubs(:format).with(:two).returns two
    Puppet::Network::FormatHandler.stubs(:format).with(:three).returns three
    Puppet::Network::FormatHandler.stubs(:format).with(:four).returns four
    result = FormatTester.supported_formats
    result.length.should == 2
    result.should be_include(:one)
    result.should be_include(:three)
  end

  it "should return the supported formats in decreasing order of weight" do
    one = stub 'supported', :supported? => true, :name => :one, :weight => 1
    two = stub 'supported', :supported? => true, :name => :two, :weight => 6
    three = stub 'supported', :supported? => true, :name => :three, :weight => 2
    four = stub 'supported', :supported? => true, :name => :four, :weight => 8
    Puppet::Network::FormatHandler.stubs(:formats).returns [:one, :two, :three, :four]
    Puppet::Network::FormatHandler.stubs(:format).with(:one).returns one
    Puppet::Network::FormatHandler.stubs(:format).with(:two).returns two
    Puppet::Network::FormatHandler.stubs(:format).with(:three).returns three
    Puppet::Network::FormatHandler.stubs(:format).with(:four).returns four
    FormatTester.supported_formats.should == [:four, :two, :three, :one]
  end


  describe "with a preferred serialization format setting" do
    before do
      one = stub 'supported', :supported? => true, :name => :one, :weight => 1
      two = stub 'supported', :supported? => true, :name => :two, :weight => 6
      Puppet::Network::FormatHandler.stubs(:formats).returns [:one, :two]
      Puppet::Network::FormatHandler.stubs(:format).with(:one).returns one
      Puppet::Network::FormatHandler.stubs(:format).with(:two).returns two
    end
    describe "that is supported" do
      before do
        Puppet.settings.expects(:value).with(:preferred_serialization_format).returns :one
      end
      it "should return the preferred serialization format first" do
        FormatTester.supported_formats.should == [:one, :two]
      end
    end
    describe "that is not supported" do
      before do
        Puppet.settings.expects(:value).with(:preferred_serialization_format).returns :unsupported
      end
      it "should still return the default format first" do
        FormatTester.supported_formats.should == [:two, :one]
      end
      it "should log a debug message" do
        Puppet.expects(:debug).with("Value of 'preferred_serialization_format' (unsupported) is invalid for FormatTester, using default (two)")
        Puppet.expects(:debug).with("FormatTester supports formats: one two; using two")
        FormatTester.supported_formats
      end
    end
  end

  it "should return the first format as the default format" do
    FormatTester.expects(:supported_formats).returns [:one, :two]
    FormatTester.default_format.should == :one
  end

  it "should be able to use a protected format for better logging on errors" do
    Puppet::Network::FormatHandler.should respond_to(:protected_format)
  end

  it "should delegate all methods from the informative format to the specified format" do
    format = mock 'format'
    format.stubs(:name).returns(:myformat)
    Puppet::Network::FormatHandler.expects(:format).twice.with(:myformat).returns format

    format.expects(:render).with("foo").returns "yay"
    Puppet::Network::FormatHandler.protected_format(:myformat).render("foo").should == "yay"
  end

  it "should provide better logging if a failure is encountered when delegating from the informative format to the real format" do
    format = mock 'format'
    format.stubs(:name).returns(:myformat)
    Puppet::Network::FormatHandler.expects(:format).twice.with(:myformat).returns format

    format.expects(:render).with("foo").raises "foo"
    lambda { Puppet::Network::FormatHandler.protected_format(:myformat).render("foo") }.should raise_error(Puppet::Network::FormatHandler::FormatError)
  end

  it "should raise an error if we couldn't find a format by name or mime-type" do
    Puppet::Network::FormatHandler.stubs(:format).with(:myformat).returns nil
    lambda { Puppet::Network::FormatHandler.protected_format(:myformat) }.should raise_error
  end

  describe "when using formats" do
    before do
      @format = mock 'format'
      @format.stubs(:supported?).returns true
      @format.stubs(:name).returns :my_format
      Puppet::Network::FormatHandler.stubs(:format).with(:my_format).returns @format
      Puppet::Network::FormatHandler.stubs(:mime).with("text/myformat").returns @format
      Puppet::Network::Format.stubs(:===).returns false
      Puppet::Network::Format.stubs(:===).with(@format).returns true
    end

    it "should be able to test whether a format is supported" do
      FormatTester.should respond_to(:support_format?)
    end

    it "should use the Format to determine whether a given format is supported" do
      @format.expects(:supported?).with(FormatTester)
      FormatTester.support_format?(:my_format)
    end

    it "should be able to convert from a given format" do
      FormatTester.should respond_to(:convert_from)
    end

    it "should call the format-specific converter when asked to convert from a given format" do
      @format.expects(:intern).with(FormatTester, "mydata")
      FormatTester.convert_from(:my_format, "mydata")
    end

    it "should call the format-specific converter when asked to convert from a given format by mime-type" do
      @format.expects(:intern).with(FormatTester, "mydata")
      FormatTester.convert_from("text/myformat", "mydata")
    end

    it "should call the format-specific converter when asked to convert from a given format by format instance" do
      @format.expects(:intern).with(FormatTester, "mydata")
      FormatTester.convert_from(@format, "mydata")
    end

    it "should raise a FormatError when an exception is encountered when converting from a format" do
      @format.expects(:intern).with(FormatTester, "mydata").raises "foo"
      lambda { FormatTester.convert_from(:my_format, "mydata") }.should raise_error(Puppet::Network::FormatHandler::FormatError)
    end

    it "should be able to use a specific hook for converting into multiple instances" do
      @format.expects(:intern_multiple).with(FormatTester, "mydata")

      FormatTester.convert_from_multiple(:my_format, "mydata")
    end

    it "should raise a FormatError when an exception is encountered when converting multiple items from a format" do
      @format.expects(:intern_multiple).with(FormatTester, "mydata").raises "foo"
      lambda { FormatTester.convert_from_multiple(:my_format, "mydata") }.should raise_error(Puppet::Network::FormatHandler::FormatError)
    end

    it "should be able to use a specific hook for rendering multiple instances" do
      @format.expects(:render_multiple).with("mydata")

      FormatTester.render_multiple(:my_format, "mydata")
    end

    it "should raise a FormatError when an exception is encountered when rendering multiple items into a format" do
      @format.expects(:render_multiple).with("mydata").raises "foo"
      lambda { FormatTester.render_multiple(:my_format, "mydata") }.should raise_error(Puppet::Network::FormatHandler::FormatError)
    end
  end

  describe "when managing formats" do
    it "should have a method for defining a new format" do
      Puppet::Network::FormatHandler.should respond_to(:create)
    end

    it "should create a format instance when asked" do
      format = stub 'format', :name => :foo
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

    it "should be able to retrieve a format by extension" do
      format = Puppet::Network::FormatHandler.create(:by_extension, :extension => "foo")
      Puppet::Network::FormatHandler.format_by_extension("foo").should equal(format)
    end

    it "should return nil if asked to return a format by an unknown extension" do
      Puppet::Network::FormatHandler.format_by_extension("yayness").should be_nil
    end

    it "should be able to retrieve formats by name irrespective of case and class" do
      format = Puppet::Network::FormatHandler.create(:by_name)
      Puppet::Network::FormatHandler.format(:By_Name).should equal(format)
    end

    it "should be able to retrieve a format by mime type" do
      format = Puppet::Network::FormatHandler.create(:by_name, :mime => "foo/bar")
      Puppet::Network::FormatHandler.mime("foo/bar").should equal(format)
    end

    it "should be able to retrieve a format by mime type irrespective of case" do
      format = Puppet::Network::FormatHandler.create(:by_name, :mime => "foo/bar")
      Puppet::Network::FormatHandler.mime("Foo/Bar").should equal(format)
    end

    it "should be able to return all formats" do
      one = stub 'one', :name => :one
      two = stub 'two', :name => :two
      Puppet::Network::Format.expects(:new).with(:one).returns(one)
      Puppet::Network::Format.expects(:new).with(:two).returns(two)

      Puppet::Network::FormatHandler.create(:one)
      Puppet::Network::FormatHandler.create(:two)

      list = Puppet::Network::FormatHandler.formats
      list.should be_include(:one)
      list.should be_include(:two)
    end
  end

  describe "when an instance" do
    it "should be able to test whether a format is supported" do
      FormatTester.new.should respond_to(:support_format?)
    end

    it "should be able to convert to a given format" do
      FormatTester.new.should respond_to(:render)
    end

    it "should be able to get a format mime-type" do
      FormatTester.new.should respond_to(:mime)
    end

    it "should raise a FormatError when a rendering error is encountered" do
      format = stub 'rendering format', :supported? => true, :name => :foo
      Puppet::Network::FormatHandler.stubs(:format).with(:foo).returns format

      tester = FormatTester.new
      format.expects(:render).with(tester).raises "eh"

      lambda { tester.render(:foo) }.should raise_error(Puppet::Network::FormatHandler::FormatError)
    end

    it "should call the format-specific converter when asked to convert to a given format" do
      format = stub 'rendering format', :supported? => true, :name => :foo

      Puppet::Network::FormatHandler.stubs(:format).with(:foo).returns format

      tester = FormatTester.new
      format.expects(:render).with(tester).returns "foo"

      tester.render(:foo).should == "foo"
    end

    it "should call the format-specific converter when asked to convert to a given format by mime-type" do
      format = stub 'rendering format', :supported? => true, :name => :foo
      Puppet::Network::FormatHandler.stubs(:mime).with("text/foo").returns format
      Puppet::Network::FormatHandler.stubs(:format).with(:foo).returns format

      tester = FormatTester.new
      format.expects(:render).with(tester).returns "foo"

      tester.render("text/foo").should == "foo"
    end

    it "should call the format converter when asked to convert to a given format instance" do
      format = stub 'rendering format', :supported? => true, :name => :foo
      Puppet::Network::Format.stubs(:===).with(format).returns(true)
      Puppet::Network::FormatHandler.stubs(:format).with(:foo).returns format

      tester = FormatTester.new
      format.expects(:render).with(tester).returns "foo"

      tester.render(format).should == "foo"
    end

    it "should render to the default format if no format is provided when rendering" do
      format = stub 'rendering format', :supported? => true, :name => :foo
      Puppet::Network::FormatHandler.stubs(:format).with(:foo).returns format

      FormatTester.expects(:default_format).returns :foo
      tester = FormatTester.new

      format.expects(:render).with(tester)
      tester.render
    end

    it "should call the format-specific converter when asked for the mime-type of a given format" do
      format = stub 'rendering format', :supported? => true, :name => :foo

      Puppet::Network::FormatHandler.stubs(:format).with(:foo).returns format

      tester = FormatTester.new
      format.expects(:mime).returns "text/foo"

      tester.mime(:foo).should == "text/foo"
    end

    it "should return the default format mime-type if no format is provided" do
      format = stub 'rendering format', :supported? => true, :name => :foo
      Puppet::Network::FormatHandler.stubs(:format).with(:foo).returns format

      FormatTester.expects(:default_format).returns :foo
      tester = FormatTester.new

      format.expects(:mime).returns "text/foo"
      tester.mime.should == "text/foo"
    end
  end
end
