#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/indirector/memory'

require 'shared_behaviours/memory_terminus'

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

        @request = stub 'request', :key => @name, :instance => @instance
    end
end
