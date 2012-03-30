#!/usr/bin/env rspec
require 'spec_helper'

describe "the 'fail' parser function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  let :scope do
    scope = Puppet::Parser::Scope.new
    scope.stubs(:environment).returns(nil)
    scope
  end

  it "should exist" do
    Puppet::Parser::Functions.function(:fail).should == "function_fail"
  end

  it "should raise a parse error if invoked" do
    expect { scope.function_fail([]) }.to raise_error Puppet::ParseError
  end

  it "should join arguments into a string in the error" do
    expect { scope.function_fail(["hello", "world"]) }.to raise_error /hello world/
  end
end
