#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe "the require function" do

    before :each do
        @parser = Puppet::Parser::Parser.new :Code => ""
        @node = Puppet::Node.new("mynode")
        @compiler = Puppet::Parser::Compiler.new(@node, @parser)

        @compiler.send(:evaluate_main)
        @scope = @compiler.topscope
        # preload our functions
        Puppet::Parser::Functions.function(:include)
        Puppet::Parser::Functions.function(:require)
    end

    it "should add a relationship between the 'required' class and our class" do
        @parser.newclass("requiredclass")

        @scope.function_require("requiredclass")

        @compiler.catalog.edge?(@scope.resource,@compiler.findresource(:class,"requiredclass")).should be_true
    end

end
