#! /usr/bin/env ruby
require 'spec_helper'

whit = Puppet::Type.type(:whit)

describe whit do
  it "should stringify in a way that users will regognise" do
    whit.new(:name => "Foo::Bar").to_s.should == "Foo::Bar"
  end
end
