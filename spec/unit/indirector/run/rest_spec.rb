#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/run/rest'

describe Puppet::Run::Rest do
  it "should be a sublcass of Puppet::Indirector::REST" do
    Puppet::Run::Rest.superclass.should equal(Puppet::Indirector::REST)
  end
end
