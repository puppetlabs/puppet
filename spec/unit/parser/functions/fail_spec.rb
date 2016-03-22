#! /usr/bin/env ruby
require 'spec_helper'

describe "the 'fail' parser function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  let :scope do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    scope    = Puppet::Parser::Scope.new(compiler)
    scope.stubs(:environment).returns(nil)
    scope
  end

  it "should exist" do
    expect(Puppet::Parser::Functions.function(:fail)).to eq("function_fail")
  end

  it "should raise a parse error if invoked" do
    expect { scope.function_fail([]) }.to raise_error Puppet::ParseError
  end

  it "should join arguments into a string in the error" do
    expect { scope.function_fail(["hello", "world"]) }.to raise_error /hello world/
  end
end
