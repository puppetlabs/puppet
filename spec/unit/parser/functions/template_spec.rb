#! /usr/bin/env ruby
require 'spec_helper'

describe "the template function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  let :node     do Puppet::Node.new('localhost') end
  let :compiler do Puppet::Parser::Compiler.new(node) end
  let :scope    do Puppet::Parser::Scope.new(compiler) end

  it "should exist" do
    Puppet::Parser::Functions.function("template").should == "function_template"
  end

  it "should create a TemplateWrapper when called" do
    tw = stub_everything 'template_wrapper'

    Puppet::Parser::TemplateWrapper.expects(:new).returns(tw)

    scope.function_template(["test"])
  end

  it "should give the template filename to the TemplateWrapper" do
    tw = stub_everything 'template_wrapper'
    Puppet::Parser::TemplateWrapper.stubs(:new).returns(tw)

    tw.expects(:file=).with("test")

    scope.function_template(["test"])
  end

  it "should return what TemplateWrapper.result returns" do
    tw = stub_everything 'template_wrapper'
    Puppet::Parser::TemplateWrapper.stubs(:new).returns(tw)
    tw.stubs(:file=).with("test")

    tw.expects(:result).returns("template contents evaluated")

    scope.function_template(["test"]).should == "template contents evaluated"
  end

  it "should concatenate template wrapper outputs for multiple templates" do
    tw1 = stub_everything "template_wrapper1"
    tw2 = stub_everything "template_wrapper2"
    Puppet::Parser::TemplateWrapper.stubs(:new).returns(tw1,tw2)
    tw1.stubs(:file=).with("1")
    tw2.stubs(:file=).with("2")
    tw1.stubs(:result).returns("result1")
    tw2.stubs(:result).returns("result2")

    scope.function_template(["1","2"]).should == "result1result2"
  end

  it "should raise an error if the template raises an error" do
    tw = stub_everything 'template_wrapper'
    Puppet::Parser::TemplateWrapper.stubs(:new).returns(tw)
    tw.stubs(:result).raises

    expect {
      scope.function_template(["1"])
    }.to raise_error(Puppet::ParseError, /Failed to parse template/)
  end

  def eval_template(content, *rest)
    File.stubs(:read).with("template").returns(content)
    Puppet::Parser::Files.stubs(:find_template).returns("template")
    scope.function_template(['template'] + rest)
  end

  it "should handle legacy template variable access correctly" do
    expect {
      eval_template("template <%= deprecated %>")
    }.to raise_error(Puppet::ParseError)
  end

  it "should get values from the scope correctly" do
    scope["deprecated"] = "deprecated value"
    eval_template("template <%= deprecated %>").should == "template deprecated value"
  end

  it "should handle kernel shadows without raising" do
    expect { eval_template("<%= binding %>") }.to_not raise_error
  end

  it "should not see scopes" do
    scope['myvar'] = 'this is yayness'
    expect {
      eval_template("<%= lookupvar('myvar') %>")
    }.to raise_error(Puppet::ParseError)
  end

  { "" => "", false => "false", true => "true" }.each do |input, output|
    it "should support defined variables (#{input.inspect} => #{output.inspect})" do
      scope['yayness'] = input
      expect {
        eval_template("<%= @yayness %>").should == output
      }.to_not raise_error
    end
  end
end
