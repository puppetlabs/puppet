#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:stage) do
  it "should have a 'name' parameter'" do
    Puppet::Type.type(:stage).new(:name => :foo)[:name].should == :foo
  end
end
