#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/parser/templatewrapper'

describe Puppet::Parser::TemplateWrapper do
  before(:each) do
    @known_resource_types = Puppet::Resource::TypeCollection.new("env")
    @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("mynode"))
    @compiler.environment.stubs(:known_resource_types).returns @known_resource_types
    @scope = Puppet::Parser::Scope.new :compiler => @compiler

    @file = "fake_template"
    Puppet::Parser::Files.stubs(:find_template).returns("/tmp/fake_template")
    FileTest.stubs(:exists?).returns("true")
    File.stubs(:read).with("/tmp/fake_template").returns("template content")
    @tw = Puppet::Parser::TemplateWrapper.new(@scope)
  end

  def mock_template(source=nil)
    template_mock = mock("template", :result => "woot!")
    ERB.expects(:new).with("template contents", 0, "-").returns(template_mock)
    template_mock.expects(:filename=).with(source)
  end

  it "should create a new object TemplateWrapper from a scope" do
    tw = Puppet::Parser::TemplateWrapper.new(@scope)

    tw.should be_a_kind_of(Puppet::Parser::TemplateWrapper)
  end

  it "should check template file existance and read its content" do
    Puppet::Parser::Files.expects(:find_template).with("fake_template", @scope.environment.to_s).returns("/tmp/fake_template")
    File.expects(:read).with("/tmp/fake_template").returns("template content")

    @tw.file = @file
  end

  it "should mark the file for watching" do
    Puppet::Parser::Files.expects(:find_template).returns("/tmp/fake_template")
    File.stubs(:read)

    @known_resource_types.expects(:watch_file).with("/tmp/fake_template")
    @tw.file = @file
  end

  it "should fail if a template cannot be found" do
    Puppet::Parser::Files.expects(:find_template).returns nil

    lambda { @tw.file = @file }.should raise_error(Puppet::ParseError)
  end

  it "should turn into a string like template[name] for file based template" do
    @tw.file = @file
    @tw.to_s.should eql("template[/tmp/fake_template]")
  end

  it "should turn into a string like template[inline] for string-based template" do
    @tw.to_s.should eql("template[inline]")
  end

  it "should return the processed template contents with a call to result" do
    mock_template("/tmp/fake_template")
    File.expects(:read).with("/tmp/fake_template").returns("template contents")

    @tw.file = @file
    @tw.result.should eql("woot!")
  end

  it "should return the processed template contents with a call to result and a string" do
    mock_template
    @tw.result("template contents").should eql("woot!")
  end

  it "should return the contents of a variable if called via method_missing" do
    @scope.expects(:lookupvar).with { |name,options| name == "chicken"}.returns("is good")
    tw = Puppet::Parser::TemplateWrapper.new(@scope)
    tw.chicken.should eql("is good")
  end

  it "should throw an exception if a variable is called via method_missing and it does not exist" do
    @scope.expects(:lookupvar).with { |name,options| name == "chicken"}.returns(:undefined)
    tw = Puppet::Parser::TemplateWrapper.new(@scope)
    lambda { tw.chicken }.should raise_error(Puppet::ParseError)
  end

  it "should allow you to check whether a variable is defined with has_variable?" do
    @scope.expects(:lookupvar).with { |name,options| name == "chicken"}.returns("is good")
    tw = Puppet::Parser::TemplateWrapper.new(@scope)
    tw.has_variable?("chicken").should eql(true)
  end

  it "should allow you to check whether a variable is not defined with has_variable?" do
    @scope.expects(:lookupvar).with { |name,options| name == "chicken"}.returns(:undefined)
    tw = Puppet::Parser::TemplateWrapper.new(@scope)
    tw.has_variable?("chicken").should eql(false)
  end

  it "should allow you to retrieve the defined classes with classes" do
    catalog = mock 'catalog', :classes => ["class1", "class2"]
    @scope.expects(:catalog).returns( catalog )
    tw = Puppet::Parser::TemplateWrapper.new(@scope)
    tw.classes.should == ["class1", "class2"]
  end

  it "should allow you to retrieve all the tags with all_tags" do
    catalog = mock 'catalog', :tags => ["tag1", "tag2"]
    @scope.expects(:catalog).returns( catalog )
    tw = Puppet::Parser::TemplateWrapper.new(@scope)
    tw.all_tags.should == ["tag1","tag2"]
  end

  it "should allow you to retrieve the tags defined in the current scope" do
    @scope.expects(:tags).returns( ["tag1", "tag2"] )
    tw = Puppet::Parser::TemplateWrapper.new(@scope)
    tw.tags.should == ["tag1","tag2"]
  end

  it "should set all of the scope's variables as instance variables" do
    mock_template
    @scope.expects(:to_hash).returns("one" => "foo")
    @tw.result("template contents")

    @tw.instance_variable_get("@one").should == "foo"
  end

  it "should not error out if one of the variables is a symbol" do
    mock_template

    @scope.expects(:to_hash).returns(:_timestamp => "1234")
    @tw.result("template contents")
  end

  %w{! . ; :}.each do |badchar|
    it "should translate #{badchar} to _ when setting the instance variables" do
      mock_template
      @scope.expects(:to_hash).returns("one#{badchar}" => "foo")
      @tw.result("template contents")

      @tw.instance_variable_get("@one_").should == "foo"
    end
  end
end
