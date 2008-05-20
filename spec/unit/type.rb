#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

describe Puppet::Type, " when in a configuration" do
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
