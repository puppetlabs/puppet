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
end
