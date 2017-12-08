#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/facts/rest'

describe Puppet::Node::Facts::Rest do
  it "should be a sublcass of Puppet::Indirector::REST" do
    Puppet::Node::Facts::Rest.superclass.should equal(Puppet::Indirector::REST)
  end
end
