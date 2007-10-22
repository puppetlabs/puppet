#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/file_content/local'

describe Puppet::Indirector::FileContent::Local do
    it "should be registered with the file_content indirection" do
        Puppet::Indirector::Terminus.terminus_class(:file_content, :local).should equal(Puppet::Indirector::FileContent::Local)
    end

    it "should be a subclass of the File terminus" do
        Puppet::Indirector::FileContent::Local.superclass.should equal(Puppet::Indirector::File)
    end
end

describe Puppet::Indirector::FileContent::Local, "when finding a single file" do
    it "should return a Content instance created with the full path to the file if the file exists" do
        @content = Puppet::Indirector::FileContent::Local.new
        @uri = "file:///my/local"

        FileTest.expects(:exists?).with("/my/local").returns true
        Puppet::FileServing::Content.expects(:new).with("/my/local").returns(:mycontent)
        @content.find(@uri).should == :mycontent
    end

    it "should return nil if the file does not exist" do
        @content = Puppet::Indirector::FileContent::Local.new
        @uri = "file:///my/local"

        FileTest.expects(:exists?).with("/my/local").returns false
        @content.find(@uri).should be_nil
    end
end
