#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::AST::Node do
    before :each do
        @node = Puppet::Node.new "testnode"
        @parser = Puppet::Parser::Parser.new :environment => "development"
        @scope_resource = stub 'scope_resource', :builtin? => true
        @compiler = Puppet::Parser::Compiler.new(@node, @parser)

        @scope = @compiler.topscope
    end

    describe Puppet::Parser::AST::Node, "when evaluating" do

        before do
            @top = @parser.newnode("top").shift
            @middle = @parser.newnode("middle", :parent => "top").shift
        end

        it "should create a resource that references itself" do
            @top.evaluate(@scope)

            @compiler.catalog.resource(:node, "top").should be_an_instance_of(Puppet::Parser::Resource)
        end

        it "should evaluate the parent class if one exists" do
            @middle.evaluate(@scope)

            @compiler.catalog.resource(:node, "top").should be_an_instance_of(Puppet::Parser::Resource)
        end

        it "should fail to evaluate if a parent class is defined but cannot be found" do
            othertop = @parser.newnode("something", :parent => "yay").shift
            lambda { othertop.evaluate(@scope) }.should raise_error(Puppet::ParseError)
        end

        it "should not create a new resource if one already exists" do
            @compiler.catalog.expects(:resource).with(:node, "top").returns("something")
            @compiler.catalog.expects(:add_resource).never
            @top.evaluate(@scope)
        end

        it "should not create a new parent resource if one already exists and it has a parent class" do
            @top.evaluate(@scope)

            top_resource = @compiler.catalog.resource(:node, "top")

            @middle.evaluate(@scope)

            @compiler.catalog.resource(:node, "top").should equal(top_resource)
        end

        # #795 - tag before evaluation.
        it "should tag the catalog with the resource tags when it is evaluated" do
            @middle.evaluate(@scope)

            @compiler.catalog.should be_tagged("middle")
        end

        it "should tag the catalog with the parent class tags when it is evaluated" do
            @middle.evaluate(@scope)

            @compiler.catalog.should be_tagged("top")
        end
    end

    describe Puppet::Parser::AST::Node, "when evaluating code" do

        before do
            @top_resource = stub "top_resource"
            @top = @parser.newnode("top", :code => @top_resource).shift

            @middle_resource = stub "middle_resource"
            @middle = @parser.newnode("middle", :parent => "top", :code => @middle_resource).shift
        end

        it "should evaluate the code referred to by the class" do
            @top_resource.expects(:safeevaluate)

            resource = @top.evaluate(@scope)

            @top.evaluate_code(resource)
        end

        it "should evaluate the parent class's code if it has a parent" do
            @top_resource.expects(:safeevaluate)
            @middle_resource.expects(:safeevaluate)

            resource = @middle.evaluate(@scope)

            @middle.evaluate_code(resource)
        end

        it "should not evaluate the parent class's code if the parent has already been evaluated" do
            @top_resource.stubs(:safeevaluate)
            resource = @top.evaluate(@scope)
            @top.evaluate_code(resource)

            @top_resource.expects(:safeevaluate).never
            @middle_resource.stubs(:safeevaluate)
            resource = @middle.evaluate(@scope)
            @middle.evaluate_code(resource)
        end

        it "should use the parent class's scope as its parent scope" do
            @top_resource.stubs(:safeevaluate)
            @middle_resource.stubs(:safeevaluate)
            resource = @middle.evaluate(@scope)
            @middle.evaluate_code(resource)

            @compiler.class_scope(@middle).parent.should equal(@compiler.class_scope(@top))
        end

        it "should add the parent class's namespace to its namespace search path" do
            @top_resource.stubs(:safeevaluate)
            @middle_resource.stubs(:safeevaluate)
            resource = @middle.evaluate(@scope)
            @middle.evaluate_code(resource)

            @compiler.class_scope(@middle).namespaces.should be_include(@top.namespace)
        end
    end
end
