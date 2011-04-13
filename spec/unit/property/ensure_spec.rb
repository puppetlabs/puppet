#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/property/ensure'

klass = Puppet::Property::Ensure

describe klass do
  it "should be a subclass of Property" do
    klass.superclass.must == Puppet::Property
  end
end
