#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/indirector/null'

describe Puppet::Indirector::Null do
    before do
        Puppet::Indirector::Terminus.stubs(:register_terminus_class)
        @model = mock 'model'
        @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
        Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)

        @null_class = Class.new(Puppet::Indirector::Null) do
            def self.to_s
                "Testing"
            end
        end

        @searcher = @null_class.new
    end

    it "should return return an instance of the indirected model" do
        object = mock 'object'
        @model.expects(:new).with("yay").returns object
        @searcher.find("yay").should equal(object)
    end
end
