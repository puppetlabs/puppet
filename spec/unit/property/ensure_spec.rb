#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

require 'puppet/property/ensure'

klass = Puppet::Property::Ensure

describe klass do
  it "should be a subclass of Property" do
    klass.superclass.must == Puppet::Property
  end
end
