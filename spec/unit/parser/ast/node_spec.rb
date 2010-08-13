#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::AST::Node do
  describe "when instantiated" do
    it "should make its names available through an accessor" do
      node = Puppet::Parser::AST::Node.new(['foo', 'bar'])
      node.names.should == ['foo', 'bar']
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
