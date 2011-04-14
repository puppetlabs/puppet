#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/resource_type/rest'

describe Puppet::Indirector::ResourceType::Rest do
  it "should be registered with the resource_type indirection" do
    Puppet::Indirector::Terminus.terminus_class(:resource_type, :rest).should equal(Puppet::Indirector::ResourceType::Rest)
  end

  it "should be a subclass of Puppet::Indirector::Rest" do
    Puppet::Indirector::ResourceType::Rest.superclass.should == Puppet::Indirector::REST
  end
end
