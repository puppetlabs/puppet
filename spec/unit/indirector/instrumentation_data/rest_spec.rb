#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/instrumentation/data'
require 'puppet/indirector/instrumentation_data/rest'

describe Puppet::Indirector::InstrumentationData::Rest do
  it "should be a subclass of Puppet::Indirector::REST" do
    Puppet::Indirector::InstrumentationData::Rest.superclass.should equal(Puppet::Indirector::REST)
  end
end
