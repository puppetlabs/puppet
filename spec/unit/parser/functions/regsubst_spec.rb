#! /usr/bin/env ruby
require 'spec_helper'

describe "the regsubst function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
  end

  it 'should raise an ParseError' do
    expect do
      @scope.function_regsubst(
      [ 'the monkey breaks banana trees',
        'b[an]*a',
        'coconut'
      ])
    end.to raise_error(Puppet::ParseError, /converted to 4x API/)
  end
end
