#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

# LAK: FIXME This is just new tests for resources; I have
# not moved all tests over yet.
describe Puppet::Parser::Resource, " when evaluating" do
    before do
        @type = Puppet::Parser::Resource

        @parser = Puppet::Parser::Parser.new :Code => ""
        @source = @parser.newclass ""
        @definition = @parser.newdefine "mydefine"
        @class = @parser.newclass "myclass"
        @nodedef = @parser.newnode("mynode")[0]
        @node = Puppet::Node.new("yaynode")
        @compile = Puppet::Parser::Compile.new(@node, @parser)
        @scope = @compile.topscope
    end

    it "should evaluate the associated AST definition" do
        res = @type.new(:type => "mydefine", :title => "whatever", :scope => @scope, :source => @source)
        @definition.expects(:evaluate).with(:scope => @scope, :resource => res)

        res.evaluate
    end

    it "should evaluate the associated AST class" do
        res = @type.new(:type => "class", :title => "myclass", :scope => @scope, :source => @source)
        @class.expects(:evaluate).with(:scope => @scope, :resource => res)
        res.evaluate
    end

    it "should evaluate the associated AST node" do
        res = @type.new(:type => "node", :title => "mynode", :scope => @scope, :source => @source)
        @nodedef.expects(:evaluate).with(:scope => @scope, :resource => res)
        res.evaluate
    end
end
