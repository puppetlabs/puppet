#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Parser::Parser do
    module ParseMatcher
        class ParseAs
            def initialize(klass)
                @parser = Puppet::Parser::Parser.new "development"
                @class = klass
            end

            def result_instance
                @result.hostclass("").code[0]
            end

            def matches?(string)
                @string = string
                @result = @parser.parse(string)
                return result_instance.instance_of?(@class)
            end

            def description
                "parse as a #{@class}"
            end

            def failure_message
                " expected #{@string} to parse as #{@class} but was #{result_instance.class}"
            end

            def negative_failure_message
                " expected #{@string} not to parse as #{@class}"
            end
        end

        def parse_as(klass)
            ParseAs.new(klass)
        end

        class ParseWith
            def initialize(block)
                @parser = Puppet::Parser::Parser.new "development"
                @block = block
            end

            def result_instance
                @result.hostclass("").code[0]
            end

            def matches?(string)
                @string = string
                @result = @parser.parse(string)
                return @block.call(result_instance)
            end

            def description
                "parse with the block evaluating to true"
            end

            def failure_message
                " expected #{@string} to parse with a true result in the block"
            end

            def negative_failure_message
                " expected #{@string} not to parse with a true result in the block"
            end
        end

        def parse_with(&block)
            ParseWith.new(block)
        end
    end

    include ParseMatcher

    before :each do
        @resource_type_collection = Puppet::Resource::TypeCollection.new("env")
        @parser = Puppet::Parser::Parser.new "development"
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

    describe "when parsing" do
        it "should be able to parse normal left to right relationships" do
            "Notify[foo] -> Notify[bar]".should parse_as(Puppet::Parser::AST::Relationship)
        end

        it "should be able to parse right to left relationships" do
            "Notify[foo] <- Notify[bar]".should parse_as(Puppet::Parser::AST::Relationship)
        end

        it "should be able to parse normal left to right subscriptions" do
            "Notify[foo] ~> Notify[bar]".should parse_as(Puppet::Parser::AST::Relationship)
        end

        it "should be able to parse right to left subscriptions" do
            "Notify[foo] <~ Notify[bar]".should parse_as(Puppet::Parser::AST::Relationship)
        end

        it "should correctly set the arrow type of a relationship" do
            "Notify[foo] <~ Notify[bar]".should parse_with { |rel| rel.arrow == "<~" }
        end
    end
end
