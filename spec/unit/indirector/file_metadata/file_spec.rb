#!/usr/bin/env rspec
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require 'spec_helper'

require 'puppet/indirector/file_metadata/file'

describe Puppet::Indirector::FileMetadata::File do
  it "should be registered with the file_metadata indirection" do
    Puppet::Indirector::Terminus.terminus_class(:file_metadata, :file).should equal(Puppet::Indirector::FileMetadata::File)
  end

  it "should be a subclass of the DirectFileServer terminus" do
    Puppet::Indirector::FileMetadata::File.superclass.should equal(Puppet::Indirector::DirectFileServer)
  end

  describe "when creating the instance for a single found file" do
    before do
      @metadata = Puppet::Indirector::FileMetadata::File.new
      @uri = "file:///my/local"
      @data = mock 'metadata'
      @data.stubs(:collect)
      FileTest.expects(:exists?).with("/my/local").returns true

      @request = Puppet::Indirector::Request.new(:file_metadata, :find, @uri)
    end

    it "should collect its attributes when a file is found" do
      @data.expects(:collect)

      Puppet::FileServing::Metadata.expects(:new).returns(@data)
      @metadata.find(@request).should == @data
    end
  end

  describe "when searching for multiple files" do
    before do
      @metadata = Puppet::Indirector::FileMetadata::File.new
      @uri = "file:///my/local"

      @request = Puppet::Indirector::Request.new(:file_metadata, :find, @uri)
    end

    it "should collect the attributes of the instances returned" do
      FileTest.expects(:exists?).with("/my/local").returns true
      @metadata.expects(:path2instances).returns( [mock("one", :collect => nil), mock("two", :collect => nil)] )
      @metadata.search(@request)
    end
  end
end
