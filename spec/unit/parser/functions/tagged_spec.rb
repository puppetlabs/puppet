#! /usr/bin/env ruby
require 'spec_helper'

describe "the 'tagged' function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
  end

  it "should exist" do
    expect(Puppet::Parser::Functions.function(:tagged)).to eq("function_tagged")
  end

  it 'is not available when --tasks is on' do
    Puppet[:tasks] = true
    expect do
      @scope.function_tagged(['one', 'two'])
    end.to raise_error(Puppet::ParseError, /is only available when compiling a catalog/)
  end

  it 'should be case-insensitive' do
    resource = Puppet::Parser::Resource.new(:file, "/file", :scope => @scope)
    @scope.stubs(:resource).returns resource
    @scope.function_tag ["one"]

    expect(@scope.function_tagged(['One'])).to eq(true)
  end

  it 'should check if all specified tags are included' do
    resource = Puppet::Parser::Resource.new(:file, "/file", :scope => @scope)
    @scope.stubs(:resource).returns resource
    @scope.function_tag ["one"]

    expect(@scope.function_tagged(['one', 'two'])).to eq(false)
  end
end
