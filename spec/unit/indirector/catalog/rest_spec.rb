#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/catalog/rest'

describe Puppet::Resource::Catalog::Rest do
  it "should be a sublcass of Puppet::Indirector::REST" do
    expect(Puppet::Resource::Catalog::Rest.superclass).to equal(Puppet::Indirector::REST)
  end
end
