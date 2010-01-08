#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe "The include function" do
    before :each do
        @node = Puppet::Node.new("mynode")
        @compiler = Puppet::Parser::Compiler.new(@node)
        @compiler.send(:evaluate_main)
        @scope = @compiler.topscope
        # preload our functions
        Puppet::Parser::Functions.function(:include)
        Puppet::Parser::Functions.function(:require)
    end

    it "should add a containment relationship between the 'included' class and our class" do
        @compiler.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "includedclass")

        @scope.function_include("includedclass")

        klass_resource = @compiler.findresource(:class,"includedclass")
        klass_resource.should be_instance_of(Puppet::Parser::Resource)
        @compiler.catalog.should be_edge(@scope.resource, klass_resource)
    end
end
