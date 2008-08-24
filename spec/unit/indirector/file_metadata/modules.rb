#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/file_metadata/modules'

describe Puppet::Indirector::FileMetadata::Modules do
    it "should be registered with the file_metadata indirection" do
        Puppet::Indirector::Terminus.terminus_class(:file_metadata, :modules).should equal(Puppet::Indirector::FileMetadata::Modules)
    end

    it "should be a subclass of the ModuleFiles terminus" do
        Puppet::Indirector::FileMetadata::Modules.superclass.should equal(Puppet::Indirector::ModuleFiles)
    end
end

describe Puppet::Indirector::FileMetadata::Modules, " when finding metadata" do
    before do
        @finder = Puppet::Indirector::FileMetadata::Modules.new
        @finder.stubs(:environment).returns(nil)
        @module = Puppet::Module.new("mymod", "/path/to")
        @finder.stubs(:find_module).returns(@module)

        @request = Puppet::Indirector::Request.new(:metadata, :find, "puppet://hostname/modules/mymod/my/file")
    end

    it "should return nil if the file is not found" do
        FileTest.expects(:exists?).with("/path/to/files/my/file").returns false
        @finder.find(@request).should be_nil
    end

    it "should retrieve the instance's attributes if the file is found" do
        FileTest.expects(:exists?).with("/path/to/files/my/file").returns true
        instance = mock 'metadta'
        Puppet::FileServing::Metadata.expects(:new).returns instance
        instance.expects :collect_attributes
        @finder.find(@request)
    end
end
