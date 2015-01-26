#! /usr/bin/env ruby
require 'spec_helper'

whit = Puppet::Type.type(:whit)

describe whit do
  it "should stringify in a way that users will regognise" do
    expect(whit.new(:name => "Foo::Bar").to_s).to eq("Foo::Bar")
  end
end
