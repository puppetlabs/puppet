#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/resource_type/parser'

describe Puppet::Indirector::ResourceType::Parser do
    before do
        @terminus = Puppet::Indirector::ResourceType::Parser.new
        @request = Puppet::Indirector::Request.new(:resource_type, :find, "foo")
        @krt = Puppet::Resource::TypeCollection.new(@request.environment)
        @request.environment.stubs(:known_resource_types).returns @krt
    end

    it "should be registered with the resource_type indirection" do
        Puppet::Indirector::Terminus.terminus_class(:resource_type, :parser).should equal(Puppet::Indirector::ResourceType::Parser)
    end

    describe "when finding" do
        it "should use the request's environment's list of known resource types" do
            @request.environment.known_resource_types.expects(:hostclass).returns nil

            @terminus.find(@request)
        end

        it "should return any found type" do
            type = @krt.add(Puppet::Resource::Type.new(:hostclass, "foo"))

            @terminus.find(@request).should == type
        end

        it "should return nil if no type can be found" do
            @terminus.find(@request).should be_nil
        end

        it "should prefer definitions to nodes" do
            type = @krt.add(Puppet::Resource::Type.new(:hostclass, "foo"))
            node = @krt.add(Puppet::Resource::Type.new(:node, "foo"))

            @terminus.find(@request).should == type
        end
    end

    describe "when searching" do
        before do
            @request.key = "*"
        end

        it "should use the request's environment's list of known resource types" do
            @request.environment.known_resource_types.expects(:hostclasses).returns({})

            @terminus.search(@request)
        end

        it "should fail if anyther other than '*' was provided as the search key" do
            @request.key = "foo*"
            lambda { @terminus.search(@request) }.should raise_error(ArgumentError)
        end

        it "should return all known types" do
            type = @krt.add(Puppet::Resource::Type.new(:hostclass, "foo"))
            node = @krt.add(Puppet::Resource::Type.new(:node, "bar"))
            define = @krt.add(Puppet::Resource::Type.new(:definition, "baz"))

            result = @terminus.search(@request)
            result.should be_include(type)
            result.should be_include(node)
            result.should be_include(define)
        end

        it "should return nil if no types can be found" do
            @terminus.search(@request).should be_nil
        end
    end
end
