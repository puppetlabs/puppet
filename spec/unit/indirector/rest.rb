#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/indirector/rest'

describe Puppet::Indirector::REST do
    # FIXME : TODO / look through this, does this make sense?
    before do
        Puppet::Indirector::Terminus.stubs(:register_terminus_class)
        @model = mock 'model'
        @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
        Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)

        @rest_class = Class.new(Puppet::Indirector::REST) do
            def self.to_s
                "This::Is::A::Test::Class"
            end
        end

        @searcher = @rest_class.new
    end

    it "should return an instance of the indirected model"    
    it "should deserialize result data after a call into a Model instance for find"
    it "should deserialize result data after a call into a list of Model instances for search"
    it "should deserialize result data after a call into a boolean for save"
    it "should deserialize result data after a call into a boolean for destroy"
    it "should generate an error when result data deserializes improperly"
    it "should generate an error when result data specifies an error"
end
