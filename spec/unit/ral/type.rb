#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Type, " when in a configuration" do
    before do
        @configuration = Puppet::Node::Configuration.new
        @container = Puppet::Type.type(:component).create(:name => "container")
        @one = Puppet::Type.type(:file).create(:path => "/file/one")
        @two = Puppet::Type.type(:file).create(:path => "/file/two")
        @configuration.add_resource @container
        @configuration.add_resource @one
        @configuration.add_resource @two
        @configuration.add_edge! @container, @one
        @configuration.add_edge! @container, @two
    end

    it "should have no parent if there is no in edge" do
        @container.parent.should be_nil
    end

    it "should set its parent to its in edge" do
        @one.parent.ref.should equal(@container.ref)
    end
end
