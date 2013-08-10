#! /usr/bin/env ruby
require 'spec_helper'

describe 'Puppet::Parser::AST::Heredoc' do
  let(:node) { Puppet::Node.new('localhost') }
  let(:compiler) { Puppet::Parser::Compiler.new(node) }
  let(:scope) { Puppet::Parser::Scope.new(compiler) }

  before(:each) do
    Puppet[:binder] = true
  end

  it "evaluates its expression argument" do
    expr = Puppet::Parser::AST::Concat.new({:value => [
      Puppet::Parser::AST::FlatString.new(:value => 'x'),
      Puppet::Parser::AST::FlatString.new(:value => 'y')]})
    heredoc = Puppet::Parser::AST::Heredoc.new({:expr => expr})
    expect(heredoc.evaluate(scope)).to be == 'xy'
  end

  it "makes call to validate the result of the expression" do
    expr = Puppet::Parser::AST::FlatString.new(:value => 'xy')
    heredoc = Puppet::Parser::AST::Heredoc.new({:expr => expr})
    heredoc.expects(:validate).with(scope, 'xy').returns(nil)
    expect(heredoc.evaluate(scope)).to be == 'xy'
  end

  it "skips validation for unknown syntax names" do
    expr = Puppet::Parser::AST::FlatString.new(:value => ']')
    heredoc = Puppet::Parser::AST::Heredoc.new({:expr => expr, :syntax => 'marshian'})
    expect(heredoc.evaluate(scope)).to be == ']'
  end

  it "validates Json containing errors" do
    expr = Puppet::Parser::AST::FlatString.new(:value => ']')
    heredoc = Puppet::Parser::AST::Heredoc.new({:expr => expr, :syntax => 'json'})
    expect {heredoc.evaluate(scope) }.to raise_error(/Json syntax checker: Cannot parse invalid JSON string/)
  end

  it "validates using first found checker" do
    expr = Puppet::Parser::AST::FlatString.new(:value => ']')
    heredoc = Puppet::Parser::AST::Heredoc.new({:expr => expr, :syntax => 'myapp+json'})
    expect {heredoc.evaluate(scope) }.to raise_error(/Json syntax checker: Cannot parse invalid JSON string/)
  end

end

