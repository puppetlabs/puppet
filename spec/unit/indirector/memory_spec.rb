#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/indirector/memory'

require 'shared_behaviours/memory_terminus'

describe Puppet::Indirector::Memory do
  it_should_behave_like "A Memory Terminus"

  before do
    Puppet::Indirector::Terminus.stubs(:register_terminus_class)
    @model = mock 'model'
    @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
    Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)

    module Testing; end
    @memory_class = class Testing::MyMemory < Puppet::Indirector::Memory
      self
    end

    @searcher = @memory_class.new
    @name = "me"
    @instance = stub 'instance', :name => @name

    @request = stub 'request', :key => @name, :instance => @instance
  end
end
