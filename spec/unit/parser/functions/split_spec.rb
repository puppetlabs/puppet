#! /usr/bin/env ruby
require 'spec_helper'

describe "the split function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
  end

  it 'should raise a ParseError' do
    expect { @scope.function_split([ '130;236;254;10', ';']) }.to raise_error(Puppet::ParseError, /can only be called using the 4.x function API/)
  end
end
