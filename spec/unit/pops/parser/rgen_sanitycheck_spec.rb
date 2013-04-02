#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/pops'

# relative to this spec file (./) does not work as this file is loaded by rspec
require File.join(File.dirname(__FILE__), '/parser_rspec_helper')

describe "RGen working with hashes" do
  it "should be possible to create an empty hash after having required the files above" do
    # If this fails, it means the rgen addition to Array is not monkey patched as it
    # should (it will return an array instead of fail in a method_missing), and thus
    # screw up Hash's check if it can do "to_hash' or not.
    #
    Hash[[]]
  end
end
