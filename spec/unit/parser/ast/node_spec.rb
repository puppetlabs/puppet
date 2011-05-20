#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Parser::AST::Node do
  describe "when instantiated" do
    it "should make its names and context available through accessors" do
      node = Puppet::Parser::AST::Node.new(['foo', 'bar'], :line => 5)
      node.names.should == ['foo', 'bar']
      node.context.should == {:line => 5}
    end

    it "should create a node with the proper type, name, context, and module name" do
      node = Puppet::Parser::AST::Node.new(['foo'], :line => 5)
      instantiated_nodes = node.instantiate('modname')
      instantiated_nodes.length.should == 1
      instantiated_nodes[0].type.should == :node
      instantiated_nodes[0].name.should == 'foo'
      instantiated_nodes[0].line.should == 5
      instantiated_nodes[0].module_name.should == 'modname'
    end

    it "should handle multiple names" do
      node = Puppet::Parser::AST::Node.new(['foo', 'bar'])
      instantiated_nodes = node.instantiate('modname')
      instantiated_nodes.length.should == 2
      instantiated_nodes[0].name.should == 'foo'
      instantiated_nodes[1].name.should == 'bar'
    end
  end
end
