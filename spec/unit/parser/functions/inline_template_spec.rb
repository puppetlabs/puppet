#! /usr/bin/env ruby
require 'spec_helper'

describe "the inline_template function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  let(:node) { Puppet::Node.new('localhost') }
  let(:compiler) { Puppet::Parser::Compiler.new(node) }
  let(:scope) { Puppet::Parser::Scope.new(compiler) }

  it "should concatenate template wrapper outputs for multiple templates" do
    expect(inline_template("template1", "template2")).to eq("template1template2")
  end

  it "should raise an error if the template raises an error" do
    expect { inline_template("<% raise 'error' %>") }.to raise_error(Puppet::ParseError)
  end

  it "is not interfered with by a variable called 'string' (#14093)" do
    scope['string'] = "this is a variable"
    expect(inline_template("this is a template")).to eq("this is a template")
  end

  it "has access to a variable called 'string' (#14093)" do
    scope['string'] = "this is a variable"
    expect(inline_template("string was: <%= @string %>")).to eq("string was: this is a variable")
  end

  def inline_template(*templates)
    scope.function_inline_template(templates)
  end
end
