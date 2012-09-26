#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/instrumentation/indirection_probe'
require 'puppet/indirector/instrumentation_probe/rest'

describe Puppet::Indirector::InstrumentationProbe::Rest do
  it "should be a subclass of Puppet::Indirector::REST" do
    Puppet::Indirector::InstrumentationProbe::Rest.superclass.should equal(Puppet::Indirector::REST)
  end
end
