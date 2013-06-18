#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

require 'rgen/array_extensions'
require 'puppet/util/monkey_patches/rgen_patches'

describe "RGen's array extension" do
  it "should allow empty array to be converted to empty hash" do
    # If this fails, it means the rgen addition to Array is not monkey patched as it
    # should (it will return an array instead of fail in a method_missing), and thus
    # screw up Hash's check if it can do "to_hash' or not.
    #
    Hash[[]]
  end

  it "should allow empty array to be converted to a string by join" do
    # If this fails, it means that rgen addition to Array is not monkey patched as it
    # should (it will return an array instea of fail in Array#method_missing, and thus
    # screw up implicit conversion of Array to String.
    ["a", []].join(':').should == 'a:'
  end
end
