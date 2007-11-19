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

describe Puppet::Parser::Resource, " when finishing" do
    before do
        @parser = Puppet::Parser::Parser.new :Code => ""
        @source = @parser.newclass ""
        @definition = @parser.newdefine "mydefine"
        @class = @parser.newclass "myclass"
        @nodedef = @parser.newnode("mynode")[0]
        @node = Puppet::Node.new("yaynode")
        @compile = Puppet::Parser::Compile.new(@node, @parser)
        @scope = @compile.topscope

        @resource = Puppet::Parser::Resource.new(:type => "mydefine", :title => "whatever", :scope => @scope, :source => @source)
    end

    it "should copy metaparams from its scope" do
        @scope.setvar("noop", "true")

        @resource.class.publicize_methods(:add_metaparams)  { @resource.add_metaparams }

        @resource["noop"].should == "true"
    end

    it "should not copy metaparams that it already has" do
        @resource.class.publicize_methods(:set_parameter)  { @resource.set_parameter("noop", "false") }
        @scope.setvar("noop", "true")

        @resource.class.publicize_methods(:add_metaparams)  { @resource.add_metaparams }

        @resource["noop"].should == "false"
    end

    it "should stack relationship metaparams from its container if it already has them" do
        @resource.class.publicize_methods(:set_parameter)  { @resource.set_parameter("require", "resource") }
        @scope.setvar("require", "container")

        @resource.class.publicize_methods(:add_metaparams)  { @resource.add_metaparams }

        @resource["require"].sort.should == %w{container resource}
    end

    it "should flatten the array resulting from stacking relationship metaparams" do
        @resource.class.publicize_methods(:set_parameter)  { @resource.set_parameter("require", ["resource1", "resource2"]) }
        @scope.setvar("require", %w{container1 container2})

        @resource.class.publicize_methods(:add_metaparams)  { @resource.add_metaparams }

        @resource["require"].sort.should == %w{container1 container2 resource1 resource2}
    end
end
