#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/status/rest'

describe Puppet::Indirector::Status::Rest do
  it "should be a subclass of Puppet::Indirector::REST" do
    expect(Puppet::Indirector::Status::Rest.superclass).to equal(Puppet::Indirector::REST)
  end
end
