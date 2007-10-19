#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/file_metadata/mounts'

describe Puppet::Indirector::FileMetadata::Mounts do
    it "should be registered with the file_metadata indirection" do
        Puppet::Indirector::Terminus.terminus_class(:file_metadata, :mounts).should equal(Puppet::Indirector::FileMetadata::Mounts)
    end

    it "should be a subclass of the Code terminus" do
        Puppet::Indirector::FileMetadata::Mounts.superclass.should equal(Puppet::Indirector::Code)
    end
end

describe Puppet::Indirector::FileMetadata::Mounts, "when finding a single file" do
    before do
        @metadata = Puppet::Indirector::FileMetadata::Mounts.new
        @uri = "puppetmounts://host/my/local"
    end

    it "should use the path portion of the URI as the file name" do
        Puppet::FileServing::Configuration.create.expects(:file_path).with("/my/local")
        @metadata.find(@uri)
    end

    it "should use the FileServing configuration to convert the file name to a fully qualified path" do
        Puppet::FileServing::Configuration.create.expects(:file_path).with("/my/local")
        @metadata.find(@uri)
    end

    it "should return nil if no fully qualified path is found" do
        Puppet::FileServing::Configuration.create.expects(:file_path).with("/my/local").returns(nil)
        @metadata.find(@uri).should be_nil
    end

    it "should return nil if the configuration returns a file path that does not exist" do
        Puppet::FileServing::Configuration.create.expects(:file_path).with("/my/local").returns("/some/file")
        FileTest.expects(:exists?).with("/some/file").returns(false)
        @metadata.find(@uri).should be_nil
    end

    it "should return a Metadata instance if a file is found and it exists" do
        Puppet::FileServing::Configuration.create.expects(:file_path).with("/my/local").returns("/some/file")
        FileTest.expects(:exists?).with("/some/file").returns(true)
        Puppet::FileServing::Metadata.expects(:new).with("/some/file").returns(:mymetadata)
        @metadata.find(@uri).should == :mymetadata
    end
end

