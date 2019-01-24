require 'spec_helper'
require 'puppet/indirector/memory'

require 'shared_behaviours/memory_terminus'

describe Puppet::Indirector::Memory do
  it_should_behave_like "A Memory Terminus"

  before do
    allow(Puppet::Indirector::Terminus).to receive(:register_terminus_class)
    @model = double('model')
    @indirection = double('indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model)
    allow(Puppet::Indirector::Indirection).to receive(:instance).and_return(@indirection)

    module Testing; end
    @memory_class = class Testing::MyMemory < Puppet::Indirector::Memory
      self
    end

    @searcher = @memory_class.new
    @name = "me"
    @instance = double('instance', :name => @name)

    @request = double('request', :key => @name, :instance => @instance)
  end
end
