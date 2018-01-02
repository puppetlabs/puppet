#! /usr/bin/env ruby
require 'spec_helper'

describe "the 'tag' function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
  end

  it "should exist" do
    expect(Puppet::Parser::Functions.function(:tag)).to eq("function_tag")
  end

  it "should tag the resource with any provided tags" do
    resource = Puppet::Parser::Resource.new(:file, "/file", :scope => @scope)
    @scope.expects(:resource).returns resource

    @scope.function_tag ["one", "two"]

    expect(resource).to be_tagged("one")
    expect(resource).to be_tagged("two")
  end

  it 'is not available when --tasks is on' do
    Puppet[:tasks] = true
    expect do
      @scope.function_tag(['one', 'two'])
    end.to raise_error(Puppet::ParseError, /is only available when compiling a catalog/)
  end
end
