#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/file_collection/lookup'

class LookupTester
  include Puppet::FileCollection::Lookup
end

describe Puppet::FileCollection::Lookup do
  before do
    @tester = LookupTester.new

    @file_collection = mock 'file_collection'
    Puppet::FileCollection.stubs(:collection).returns @file_collection
  end

  it "should use the file collection to determine the index of the file name" do
    @file_collection.expects(:index).with("/my/file").returns 50

    @tester.file = "/my/file"
    @tester.file_index.should == 50
  end

  it "should return nil as the file name if no index is set" do
    @tester.file.should be_nil
  end

  it "should use the file collection to convert the index to a file name" do
    @file_collection.expects(:path).with(25).returns "/path/to/file"

    @tester.file_index = 25

    @tester.file.should == "/path/to/file"
  end

  it "should support a line attribute" do
    @tester.line = 50
    @tester.line.should == 50
  end

  it "should default to the global file collection" do
    Puppet::FileCollection.expects(:collection).returns "collection"
    @tester.file_collection.should == "collection"
  end
end
