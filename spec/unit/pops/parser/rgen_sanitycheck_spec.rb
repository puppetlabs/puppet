#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

require 'rgen/array_extensions'

describe "RGen extensions to core classes" do
  it "should be possible to create an empty hash after having required the files above" do
    # If this fails, it means the rgen addition to Array is not monkey patched as it
    # should (it will return an array instead of fail in a method_missing), and thus
    # screw up Hash's check if it can do "to_hash' or not.
    #
    Hash[[]]
  end

  it "should be possible to automatically stringify a nested, empty array during join" do
    # When this fails it means that rgen has incorrectly implemented
    # method_missing on array and is returning an array for to_str instead of
    # failing as is expected allowing stringification to occur
    expect([[]].join(":")).to eq("")
    expect(["1", []].join(":")).to eq("1:")
  end
end
