#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/file_content/mounts'

describe Puppet::Indirector::FileContent::Mounts do
    it "should be registered with the file_content indirection" do
        Puppet::Indirector::Terminus.terminus_class(:file_content, :mounts).should equal(Puppet::Indirector::FileContent::Mounts)
    end

    it "should be a subclass of the Code terminus" do
        Puppet::Indirector::FileContent::Mounts.superclass.should equal(Puppet::Indirector::Code)
    end
end

describe Puppet::Indirector::FileContent::Mounts, "when finding a single file" do
    before do
        @content = Puppet::Indirector::FileContent::Mounts.new
        @uri = "puppetmounts://host/my/local"
    end

    it "should use the path portion of the URI as the file name" do
        Puppet::FileServing::Configuration.create.expects(:file_path).with("/my/local")
        @content.find(@uri)
    end

    it "should use the FileServing configuration to convert the file name to a fully qualified path" do
        Puppet::FileServing::Configuration.create.expects(:file_path).with("/my/local")
        @content.find(@uri)
    end

    it "should return nil if no fully qualified path is found" do
        Puppet::FileServing::Configuration.create.expects(:file_path).with("/my/local").returns(nil)
        @content.find(@uri).should be_nil
    end

    it "should return nil if the configuration returns a file path that does not exist" do
        Puppet::FileServing::Configuration.create.expects(:file_path).with("/my/local").returns("/some/file")
        FileTest.expects(:exists?).with("/some/file").returns(false)
        @content.find(@uri).should be_nil
    end

    it "should return a Content instance if a file is found and it exists" do
        Puppet::FileServing::Configuration.create.expects(:file_path).with("/my/local").returns("/some/file")
        FileTest.expects(:exists?).with("/some/file").returns(true)
        Puppet::FileServing::Content.expects(:new).with("/some/file").returns(:mycontent)
        @content.find(@uri).should == :mycontent
    end
end
