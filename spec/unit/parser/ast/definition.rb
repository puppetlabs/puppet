#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::AST::Definition, "when initializing" do
end

describe Puppet::Parser::AST::Definition, "when evaluating" do
    before do
        @type = Puppet::Parser::Resource
        @parser = Puppet::Parser::Parser.new :Code => ""
        @source = @parser.newclass ""
        @definition = @parser.newdefine "mydefine"
        @node = Puppet::Node.new("yaynode")
        @compile = Puppet::Parser::Compile.new(@node, @parser)
        @scope = @compile.topscope

        @resource = Puppet::Parser::Resource.new(:type => "mydefine", :title => "myresource", :scope => @scope, :source => @source)
    end

    it "should create a new scope" do
        scope = nil
        code = mock 'code'
        code.expects(:safeevaluate).with do |options|
            options[:scope].object_id.should_not == @scope.object_id
            true
        end
        @definition.stubs(:code).returns(code)
        @definition.evaluate(:scope => @scope, :resource => @resource)
    end

#    it "should copy its namespace to the scope"
#
#    it "should mark the scope virtual if the resource is virtual"
#
#    it "should mark the scope exported if the resource is exported"
#
#    it "should set the resource's parameters as variables in the scope"
#
#    it "should set the resource's title as a variable in the scope"
#
#    it "should copy the resource's title in a 'name' variable in the scope"
#
#    it "should not copy the resource's title as the name if 'name' is one of the resource parameters"
#
#    it "should evaluate the associated code with the new scope"
end
