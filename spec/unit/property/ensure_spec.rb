#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/property/ensure'

klass = Puppet::Property::Ensure

describe klass do
  it "should be a subclass of Property" do
    expect(klass.superclass).to eq(Puppet::Property)
  end
end
