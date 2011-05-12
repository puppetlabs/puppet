#!/usr/bin/env rspec
require 'spec_helper'

whit = Puppet::Type.type(:whit).new(:name => "Foo::Bar")

describe whit do
  it "should stringify in a way that users will regognise" do
    whit.to_s.should == "Foo::Bar"
  end
end
