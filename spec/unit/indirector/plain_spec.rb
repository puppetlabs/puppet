#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/indirector/plain'

describe Puppet::Indirector::Plain do
  before do
    Puppet::Indirector::Terminus.stubs(:register_terminus_class)
    @model = mock 'model'
    @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
    Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)

    @plain_class = Class.new(Puppet::Indirector::Plain) do
      def self.to_s
        "Mystuff::Testing"
      end
    end

    @searcher = @plain_class.new

    @request = stub 'request', :key => "yay"
  end

  it "should return return an instance of the indirected model" do
    object = mock 'object'
    @model.expects(:new).with(@request.key).returns object
    @searcher.find(@request).should equal(object)
  end
end
