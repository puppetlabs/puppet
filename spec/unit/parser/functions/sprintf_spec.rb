#!/usr/bin/env rspec
require 'spec_helper'

describe "the sprintf function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    @scope = Puppet::Parser::Scope.new
  end

  it "should exist" do
    Puppet::Parser::Functions.function("sprintf").should == "function_sprintf"
  end

  it "should raise a ParseError if there is less than 1 argument" do
    lambda { @scope.function_sprintf([]) }.should( raise_error(Puppet::ParseError))
  end

  it "should format integers" do
    result = @scope.function_sprintf(["%+05d", "23"])
    result.should(eql("+0023"))
  end

  it "should format floats" do
    result = @scope.function_sprintf(["%+.2f", "2.7182818284590451"])
    result.should(eql("+2.72"))
  end

  it "should format large floats" do
    result = @scope.function_sprintf(["%+.2e", "27182818284590451"])
    str = Puppet.features.microsoft_windows? ? "+2.72e+016" : "+2.72e+16"
    result.should(eql(str))
  end

  it "should perform more complex formatting" do
    result = @scope.function_sprintf(
      [ "<%.8s:%#5o %#8X (%-8s)>",
        "overlongstring", "23", "48879", "foo" ])
    result.should(eql("<overlong:  027   0XBEEF (foo     )>"))
  end

end
