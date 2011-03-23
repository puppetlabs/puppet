#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../../spec_helper')

require 'puppet/indirector/resource/rest'

describe Puppet::Resource::Rest do
  it "should be a sublcass of Puppet::Indirector::REST" do
    Puppet::Resource::Rest.superclass.should equal(Puppet::Indirector::REST)
  end
end
