#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/network/format'

# A class with all of the necessary
# hooks.
class FormatRenderer
  def self.to_multiple_my_format(list)
  end

  def self.from_multiple_my_format(text)
  end

  def self.from_my_format(text)
  end

  def to_my_format
  end
end

describe Puppet::Network::Format do
  describe "when initializing" do
    it "should require a name" do
      lambda { Puppet::Network::Format.new }.should raise_error(ArgumentError)
    end

    it "should be able to provide its name" do
      Puppet::Network::Format.new(:my_format).name.should == :my_format
    end

    it "should always convert its name to a downcased symbol" do
      Puppet::Network::Format.new(:My_Format).name.should == :my_format
    end

    it "should be able to set its downcased mime type at initialization" do
      format = Puppet::Network::Format.new(:my_format, :mime => "Foo/Bar")
      format.mime.should == "foo/bar"
    end

    it "should default to text plus the name of the format as the mime type" do
      Puppet::Network::Format.new(:my_format).mime.should == "text/my_format"
    end

    it "should fail if unsupported options are provided" do
      lambda { Puppet::Network::Format.new(:my_format, :foo => "bar") }.should raise_error(ArgumentError)
    end
  end

  describe "instances" do
    before do
      @format = Puppet::Network::Format.new(:my_format)
    end

    it "should support being confined" do
      @format.should respond_to(:confine)
    end

    it "should not be considered suitable if confinement conditions are not met" do
      @format.confine :true => false
      @format.should_not be_suitable
    end

    it "should be able to determine if a class is supported" do
      @format.should respond_to(:supported?)
    end

    it "should consider a class to be supported if it has the individual and multiple methods for rendering and interning" do
      @format.should be_supported(FormatRenderer)
    end

    it "should default to its required methods being the individual and multiple methods for rendering and interning" do
      Puppet::Network::Format.new(:foo).required_methods.sort { |a,b| a.to_s <=> b.to_s }.should ==  [:intern_method, :intern_multiple_method, :render_multiple_method, :render_method].sort { |a,b| a.to_s <=> b.to_s }
    end

    it "should consider a class supported if the provided class has all required methods present" do
      format = Puppet::Network::Format.new(:foo)
      [:intern_method, :intern_multiple_method, :render_multiple_method, :render_method].each do |method|
        format.expects(:required_method_present?).with { |name, klass, type| name == method and klass == String }.returns true
      end

      format.should be_required_methods_present(String)
    end

    it "should consider a class not supported if any required methods are missing from the provided class" do
      format = Puppet::Network::Format.new(:foo)
      format.stubs(:required_method_present?).returns true
      format.expects(:required_method_present?).with { |name, *args| name == :intern_method }.returns false
      format.should_not be_required_methods_present(String)
    end

    it "should be able to specify the methods required for support" do
      Puppet::Network::Format.new(:foo, :required_methods => [:render_method, :intern_method]).required_methods.should == [:render_method, :intern_method]
    end

    it "should only test for required methods if specific methods are specified as required" do
      format = Puppet::Network::Format.new(:foo, :required_methods => [:intern_method])
      format.expects(:required_method_present?).with { |name, klass, type| name == :intern_method }

      format.required_methods_present?(String)
    end

    it "should not consider a class supported unless the format is suitable" do
      @format.expects(:suitable?).returns false
      @format.should_not be_supported(FormatRenderer)
    end

    it "should always downcase mimetypes" do
      @format.mime = "Foo/Bar"
      @format.mime.should == "foo/bar"
    end

    it "should support having a weight" do
      @format.should respond_to(:weight)
    end

    it "should default to a weight of of 5" do
      @format.weight.should == 5
    end

    it "should be able to override its weight at initialization" do
      Puppet::Network::Format.new(:foo, :weight => 1).weight.should == 1
    end

    it "should default to its extension being equal to its name" do
      Puppet::Network::Format.new(:foo).extension.should == "foo"
    end

    it "should support overriding the extension" do
      Puppet::Network::Format.new(:foo, :extension => "bar").extension.should == "bar"
    end
    [:intern_method, :intern_multiple_method, :render_multiple_method, :render_method].each do |method|
      it "should allow assignment of the #{method}" do
        Puppet::Network::Format.new(:foo, method => :foo).send(method).should == :foo
      end
    end
  end

  describe "when converting between instances and formatted text" do
    before do
      @format = Puppet::Network::Format.new(:my_format)
      @instance = FormatRenderer.new
    end

    it "should have a method for rendering a single instance" do
      @format.should respond_to(:render)
    end

    it "should have a method for rendering multiple instances" do
      @format.should respond_to(:render_multiple)
    end

    it "should have a method for interning text" do
      @format.should respond_to(:intern)
    end

    it "should have a method for interning text into multiple instances" do
      @format.should respond_to(:intern_multiple)
    end

    it "should return the results of calling the instance-specific render method if the method is present" do
      @instance.expects(:to_my_format).returns "foo"
      @format.render(@instance).should == "foo"
    end

    it "should return the results of calling the class-specific render_multiple method if the method is present" do
      @instance.class.expects(:to_multiple_my_format).returns ["foo"]
      @format.render_multiple([@instance]).should == ["foo"]
    end

    it "should return the results of calling the class-specific intern method if the method is present" do
      FormatRenderer.expects(:from_my_format).with("foo").returns @instance
      @format.intern(FormatRenderer, "foo").should equal(@instance)
    end

    it "should return the results of calling the class-specific intern_multiple method if the method is present" do
      FormatRenderer.expects(:from_multiple_my_format).with("foo").returns [@instance]
      @format.intern_multiple(FormatRenderer, "foo").should == [@instance]
    end

    it "should fail if asked to render and the instance does not respond to 'to_<format>'" do
      lambda { @format.render("foo") }.should raise_error(NotImplementedError)
    end

    it "should fail if asked to intern and the class does not respond to 'from_<format>'" do
      lambda { @format.intern(String, "foo") }.should raise_error(NotImplementedError)
    end

    it "should fail if asked to intern multiple and the class does not respond to 'from_multiple_<format>'" do
      lambda { @format.intern_multiple(String, "foo") }.should raise_error(NotImplementedError)
    end

    it "should fail if asked to render multiple and the instance does not respond to 'to_multiple_<format>'" do
      lambda { @format.render_multiple(["foo", "bar"]) }.should raise_error(NotImplementedError)
    end
  end
end
