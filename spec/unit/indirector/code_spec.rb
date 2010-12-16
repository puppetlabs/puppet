#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')
require 'puppet/indirector/code'

describe Puppet::Indirector::Code do
  before do
    Puppet::Indirector::Terminus.stubs(:register_terminus_class)
    @model = mock 'model'
    @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
    Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)

    @code_class = Class.new(Puppet::Indirector::Code) do
      def self.to_s
        "Mystuff::Testing"
      end
    end

    @searcher = @code_class.new
  end

  it "should not have a find() method defined" do
    @searcher.should_not respond_to(:find)
  end

  it "should not have a save() method defined" do
    @searcher.should_not respond_to(:save)
  end

  it "should not have a destroy() method defined" do
    @searcher.should_not respond_to(:destroy)
  end
end
