#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/indirector/memory'

describe "A Memory Terminus", :shared => true do
    it "should find no instances by default" do
        @searcher.find(@name).should be_nil
    end

    it "should be able to find instances that were previously saved" do
        @searcher.save(@instance)
        @searcher.find(@name).should equal(@instance)
    end

    it "should replace existing saved instances when a new instance with the same name is saved" do
        @searcher.save(@instance)
        two = stub 'second', :name => @name
        @searcher.save(two)
        @searcher.find(@name).should equal(two)
    end

    it "should be able to remove previously saved instances" do
        @searcher.save(@instance)
        @searcher.destroy(@instance.name)
        @searcher.find(@name).should be_nil
    end

    it "should fail when asked to destroy an instance that does not exist" do
        proc { @searcher.destroy(@instance) }.should raise_error(ArgumentError)
    end
end

describe Puppet::Indirector::Memory do
    it_should_behave_like "A Memory Terminus"

    before do
        Puppet::Indirector::Terminus.stubs(:register_terminus_class)
        @model = mock 'model'
        @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
        Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)

        @memory_class = Class.new(Puppet::Indirector::Memory) do
            def self.to_s
                "Mystuff::Testing"
            end
        end

        @searcher = @memory_class.new
        @name = "me"
        @instance = stub 'instance', :name => @name
    end
end
