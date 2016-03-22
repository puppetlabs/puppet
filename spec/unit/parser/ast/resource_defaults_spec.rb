#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Parser::AST::ResourceDefaults do

  ast = Puppet::Parser::AST

  before :each do
    @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("mynode"))
    @scope = Puppet::Parser::Scope.new(@compiler)
    @params = Puppet::Parser::AST::ASTArray.new({})
    @compiler.stubs(:add_override)
  end

  it "should add defaults when evaluated" do
    default = Puppet::Parser::AST::ResourceDefaults.new :type => "file", :parameters => Puppet::Parser::AST::ASTArray.new(:children => [])
    default.evaluate @scope

    @scope.lookupdefaults("file").should_not be_nil
  end
end
