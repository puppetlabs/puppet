#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Parser::Parser do
    before :each do
        @resource_type_collection = Puppet::Parser::ResourceTypeCollection.new("env")
        @parser = Puppet::Parser::Parser.new :environment => "development", :resource_type_collection => @resource_type_collection
    end

    describe "when parsing comments before statement" do
        it "should associate the documentation to the statement AST node" do
            ast = @parser.parse("""
            # comment
            class test {}
            """)

            ast.hostclass("test").doc.should == "comment\n"
        end
    end
end
