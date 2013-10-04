#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/catalog/rest'

describe Puppet::Resource::Catalog::Rest do
  it "should be a sublcass of Puppet::Indirector::REST" do
    Puppet::Resource::Catalog::Rest.superclass.should equal(Puppet::Indirector::REST)
  end
end
