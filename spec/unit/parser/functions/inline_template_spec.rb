#!/usr/bin/env rspec
require 'spec_helper'

describe "the inline_template function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  it "should exist" do
    Puppet::Parser::Functions.function("inline_template").should == "function_inline_template"
  end

  it "should create a TemplateWrapper when called" do
    tw = stub_everything 'template_wrapper'

    Puppet::Parser::TemplateWrapper.expects(:new).returns(tw)

    @scope.function_inline_template(["test"])
  end

  it "should pass the template string to TemplateWrapper.result" do
    tw = stub_everything 'template_wrapper'
    Puppet::Parser::TemplateWrapper.stubs(:new).returns(tw)

    tw.expects(:result).with("test")

    @scope.function_inline_template(["test"])
  end

  it "should return what TemplateWrapper.result returns" do
    tw = stub_everything 'template_wrapper'
    Puppet::Parser::TemplateWrapper.stubs(:new).returns(tw)

    tw.expects(:result).returns("template contents evaluated")

    @scope.function_inline_template(["test"]).should == "template contents evaluated"
  end

  it "should concatenate template wrapper outputs for multiple templates" do
    tw1 = stub_everything "template_wrapper1"
    tw2 = stub_everything "template_wrapper2"
    Puppet::Parser::TemplateWrapper.stubs(:new).returns(tw1,tw2)
    tw1.stubs(:result).returns("result1")
    tw2.stubs(:result).returns("result2")

    @scope.function_inline_template(["1","2"]).should == "result1result2"
  end

  it "should raise an error if the template raises an error" do
    tw = stub_everything 'template_wrapper'
    Puppet::Parser::TemplateWrapper.stubs(:new).returns(tw)
    tw.stubs(:result).raises

    lambda { @scope.function_inline_template(["1"]) }.should raise_error(Puppet::ParseError)
  end

end
