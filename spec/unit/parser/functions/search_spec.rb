#! /usr/bin/env ruby
require 'spec_helper'

describe "the 'search' function" do
  before :all do
    Puppet::Parser::Functions.autoloader.loadall
  end

  let :node     do Puppet::Node.new('localhost') end
  let :compiler do Puppet::Parser::Compiler.new(node) end
  let :scope    do Puppet::Parser::Scope.new(compiler) end

  it "should exist" do
    Puppet::Parser::Functions.function("search").should == "function_search"
  end

  it "should invoke #add_namespace on the scope for all inputs" do
    scope.expects(:add_namespace).with("where")
    scope.expects(:add_namespace).with("what")
    scope.expects(:add_namespace).with("who")
    scope.function_search(["where", "what", "who"])
  end

  it "is deprecated" do
    Puppet.expects(:deprecation_warning).with("The 'search' function is deprecated. See http://links.puppetlabs.com/search-function-deprecation")
    scope.function_search(['wat'])
  end
end
