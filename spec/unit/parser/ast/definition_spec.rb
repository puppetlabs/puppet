#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Parser::AST::Definition do
  it "should make its context available through an accessor" do
    definition = Puppet::Parser::AST::Definition.new('foo', :line => 5)
    definition.context.should == {:line => 5}
  end

  describe "when instantiated" do
    it "should create a definition with the proper type, name, context, and module name" do
      definition = Puppet::Parser::AST::Definition.new('foo', :line => 5)
      instantiated_definitions = definition.instantiate('modname')
      instantiated_definitions.length.should == 1
      instantiated_definitions[0].type.should == :definition
      instantiated_definitions[0].name.should == 'foo'
      instantiated_definitions[0].line.should == 5
      instantiated_definitions[0].module_name.should == 'modname'
    end
  end
end
