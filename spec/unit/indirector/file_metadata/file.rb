#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/file_metadata/file'

describe Puppet::Indirector::FileMetadata::File do
    it "should be registered with the file_metadata indirection" do
        Puppet::Indirector::Terminus.terminus_class(:file_metadata, :file).should equal(Puppet::Indirector::FileMetadata::File)
    end
end

describe Puppet::Indirector::FileMetadata::File, "when finding a single file" do
    before do
        @metadata = Puppet::Indirector::FileMetadata::File.new
        @uri = "file:///my/local"

        @data = mock 'metadata'
    end

    it "should return a Metadata instance created with the full path to the file if the file exists" do
        @data.stubs(:collect_attributes)

        FileTest.expects(:exists?).with("/my/local").returns true
        Puppet::FileServing::Metadata.expects(:new).with("/my/local", :links => nil).returns(@data)
        @metadata.find(@uri).should == @data
    end

    it "should pass the :links setting on to the created Content instance if the file exists" do
        @data.stubs(:collect_attributes)

        FileTest.expects(:exists?).with("/my/local").returns true
        Puppet::FileServing::Metadata.expects(:new).with("/my/local", :links => :manage).returns(@data)
        @metadata.find(@uri, :links => :manage)
    end

    it "should collect its attributes when a file is found" do
        @data.expects(:collect_attributes)

        FileTest.expects(:exists?).with("/my/local").returns true
        Puppet::FileServing::Metadata.expects(:new).with("/my/local", :links => nil).returns(@data)
        @metadata.find(@uri).should == @data
    end

    it "should return nil if the file does not exist" do
        FileTest.expects(:exists?).with("/my/local").returns false
        @metadata.find(@uri).should be_nil
    end
end

describe Puppet::Indirector::FileMetadata::File, "when searching for multiple files" do
    before do
        @metadata = Puppet::Indirector::FileMetadata::File.new
        @uri = "file:///my/local"
    end

    it "should return nil if the file does not exist" do
        FileTest.expects(:exists?).with("/my/local").returns false
        @metadata.find(@uri).should be_nil
    end

    it "should use :path2instances from the terminus_helper to return instances if the file exists" do
        FileTest.expects(:exists?).with("/my/local").returns true
        @metadata.expects(:path2instances).with("/my/local", {}).returns([])
        @metadata.search(@uri)
    end

    it "should pass any options on to :path2instances" do
        FileTest.expects(:exists?).with("/my/local").returns true
        @metadata.expects(:path2instances).with("/my/local", :testing => :one, :other => :two).returns([])
        @metadata.search(@uri, :testing => :one, :other => :two)
    end

    it "should collect the attributes of the instances returned" do
        FileTest.expects(:exists?).with("/my/local").returns true
        @metadata.expects(:path2instances).with("/my/local", {}).returns( [mock("one", :collect_attributes => nil), mock("two", :collect_attributes => nil)] )
        @metadata.search(@uri)
    end
end
