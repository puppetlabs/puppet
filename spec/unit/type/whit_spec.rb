#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

whit = Puppet::Type.type(:whit).new(:name => "Foo::Bar")

describe whit do
  it "should stringify as though it were the class it represents" do
    whit.to_s.should == "Class[Foo::Bar]"
  end
end
