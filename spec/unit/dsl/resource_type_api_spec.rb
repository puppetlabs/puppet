#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/dsl/resource_type_api'

class DSLAPITester
    include Puppet::DSL::ResourceTypeAPI
end

describe Puppet::DSL::ResourceTypeAPI do
    before do
        @api = DSLAPITester.new
    end

    [:definition, :node, :hostclass].each do |type|
        method = type == :definition ? "resource_type" : type
        it "should be able to create a #{type}" do
            newtype = Puppet::Resource::Type.new(:hostclass, "foo")
            Puppet::Resource::Type.expects(:new).with { |t, n, args| t == type }.returns newtype
            @api.send(method, "myname")
        end

        it "should use the provided name when creating a #{type}" do
            type = Puppet::Resource::Type.new(:hostclass, "foo")
            Puppet::Resource::Type.expects(:new).with { |t, n, args| n == "myname" }.returns type
            @api.send(method, "myname")
        end

        unless type == :definition
            it "should pass in any provided options" do
                type = Puppet::Resource::Type.new(:hostclass, "foo")
                Puppet::Resource::Type.expects(:new).with { |t, n, args| args == {:myarg => :myvalue} }.returns type
                @api.send(method, "myname", :myarg => :myvalue)
            end
        end

        it "should set any provided block as the type's ruby code"

        it "should add the type to the current environment's known resource types"
    end

    describe "when creating a definition" do
        it "should use the provided options to define valid arguments for the resource type"
    end
end
