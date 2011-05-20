#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/file_collection'

describe Puppet::FileCollection do
  before do
    @collection = Puppet::FileCollection.new
  end

  it "should be able to convert a file name into an index" do
    @collection.index("/my/file").should be_instance_of(Fixnum)
  end

  it "should be able to convert an index into a file name" do
    index = @collection.index("/path/to/file")
    @collection.path(index).should == "/path/to/file"
  end

  it "should always give the same file name for a given index" do
    index = @collection.index("/path/to/file")
    @collection.path(index).should == @collection.path(index)
  end

  it "should always give the same index for a given file name" do
    @collection.index("/my/file").should == @collection.index("/my/file")
  end

  it "should always correctly relate a file name and its index even when multiple files are in the collection" do
    indexes = %w{a b c d e f}.inject({}) do |hash, letter|
      hash[letter] = @collection.index("/path/to/file/#{letter}")
      hash
    end

    indexes.each do |letter, index|
      @collection.index("/path/to/file/#{letter}").should == indexes[letter]
      @collection.path(index).should == @collection.path(index)
    end
  end

  it "should return nil as the file name when an unknown index is provided" do
    @collection.path(50).should be_nil
  end

  it "should provide a global collection" do
    Puppet::FileCollection.collection.should be_instance_of(Puppet::FileCollection)
  end

  it "should reuse the global collection" do
    Puppet::FileCollection.collection.should equal(Puppet::FileCollection.collection)
  end
end
