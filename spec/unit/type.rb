#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

describe Puppet::Type do
    describe "when retrieving current properties" do
        # Use 'mount' as an example, because it doesn't override 'retrieve'
        before do
            @resource = Puppet::Type.type(:mount).create(:name => "foo", :fstype => "bar", :pass => 1, :ensure => :present)
            @properties = {}
        end

        after { Puppet::Type.type(:mount).clear }

        it "should return a hash containing values for all set properties" do
            values = @resource.retrieve
            [@resource.property(:fstype), @resource.property(:pass)].each { |property| values.should be_include(property) }
        end

        it "should not call retrieve on non-ensure properties if the resource is absent" do
            @resource.property(:ensure).expects(:retrieve).returns :absent
            @resource.property(:fstype).expects(:retrieve).never
            @resource.retrieve[@resource.property(:fstype)]
        end

        it "should set all values to :absent if the resource is absent" do
            @resource.property(:ensure).expects(:retrieve).returns :absent
            @resource.retrieve[@resource.property(:fstype)].should == :absent
        end

        it "should include the result of retrieving each property's current value if the resource is present" do
            @resource.property(:ensure).expects(:retrieve).returns :present
            @resource.property(:fstype).expects(:retrieve).returns 15
            @resource.retrieve[@resource.property(:fstype)].should == 15
        end
    end


    describe "when in a catalog" do
        before do
            @catalog = Puppet::Node::Catalog.new
            @container = Puppet::Type.type(:component).create(:name => "container")
            @one = Puppet::Type.type(:file).create(:path => "/file/one")
            @two = Puppet::Type.type(:file).create(:path => "/file/two")
            @catalog.add_resource @container
            @catalog.add_resource @one
            @catalog.add_resource @two
            @catalog.add_edge @container, @one
            @catalog.add_edge @container, @two
        end

        it "should have no parent if there is no in edge" do
            @container.parent.should be_nil
        end

        it "should set its parent to its in edge" do
            @one.parent.ref.should == @container.ref
        end

        after do
            @catalog.clear(true)
        end
    end
end
