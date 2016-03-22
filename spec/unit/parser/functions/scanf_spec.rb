#! /usr/bin/env ruby
require 'spec_helper'

describe "the scanf function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  let(:node) { Puppet::Node.new('localhost') }
  let(:compiler) { Puppet::Parser::Compiler.new(node) }
  let(:scope) { Puppet::Parser::Scope.new(compiler) }

  it 'scans a value and returns an array' do
    expect(scope.function_scanf(['42', '%i'])[0] == 42)
  end

  it 'returns empty array if nothing was scanned' do
    expect(scope.function_scanf(['no', '%i']) == [])
  end

  it 'produces result up to first unsuccessful scan' do
    expect(scope.function_scanf(['42 no', '%i'])[0] == 42)
  end

  it 'errors when not given enough arguments' do
    expect do
      scope.function_scanf(['42'])
    end.to raise_error(/.*scanf\(\): Wrong number of arguments given/m)
  end
end
