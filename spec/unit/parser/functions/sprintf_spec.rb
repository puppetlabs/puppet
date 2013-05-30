#! /usr/bin/env ruby
require 'spec_helper'

describe "the sprintf function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  before :each do
    node     = Puppet::Node.new('localhost')
    compiler = Puppet::Parser::Compiler.new(node)
    @scope   = Puppet::Parser::Scope.new(compiler)
  end

  it "should exist" do
    Puppet::Parser::Functions.function("sprintf").should == "function_sprintf"
  end

  it "should raise an ArgumentError if there is less than 1 argument" do
    lambda { @scope.function_sprintf([]) }.should( raise_error(ArgumentError))
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
    str =
      if Puppet.features.microsoft_windows? && RUBY_VERSION[0,3] == '1.8'
        "+2.72e+016"
      else
        "+2.72e+16"
      end
    result.should(eql(str))
  end

  it "should perform more complex formatting" do
    result = @scope.function_sprintf(
      [ "<%.8s:%#5o %#8X (%-8s)>",
        "overlongstring", "23", "48879", "foo" ])
    result.should(eql("<overlong:  027   0XBEEF (foo     )>"))
  end

end
