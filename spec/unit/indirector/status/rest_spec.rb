#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/status/rest'

describe Puppet::Indirector::Status::Rest do
  it "should be a sublcass of Puppet::Indirector::REST" do
    Puppet::Indirector::Status::Rest.superclass.should equal(Puppet::Indirector::REST)
  end
end
