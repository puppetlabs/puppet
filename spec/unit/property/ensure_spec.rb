#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/property/making_sure'

klass = Puppet::Property::MakingSure

describe klass do
  it "should be a subclass of Property" do
    klass.superclass.must == Puppet::Property
  end
end
