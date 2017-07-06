#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/resource_type/rest'

describe Puppet::Indirector::ResourceType::Rest do
  it "should be registered with the resource_type indirection" do
    expect(Puppet::Indirector::Terminus.terminus_class(:resource_type, :rest)).to equal(Puppet::Indirector::ResourceType::Rest)
  end

  it "should be a subclass of Puppet::Indirector::Rest" do
    expect(Puppet::Indirector::ResourceType::Rest.superclass).to eq(Puppet::Indirector::REST)
  end
end
