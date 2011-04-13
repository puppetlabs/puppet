#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/catalog/queue'

describe Puppet::Resource::Catalog::Queue do
  it 'should be a subclass of the Queue terminus' do
    Puppet::Resource::Catalog::Queue.superclass.should equal(Puppet::Indirector::Queue)
  end

  it 'should be registered with the catalog store indirection' do
    indirection = Puppet::Indirector::Indirection.instance(:catalog)
    Puppet::Resource::Catalog::Queue.indirection.should equal(indirection)
  end

  it 'shall be dubbed ":queue"' do
    Puppet::Resource::Catalog::Queue.name.should == :queue
  end
end
