#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/file_content/file'

describe Puppet::Indirector::FileContent::File do
    it "should be registered with the file_content indirection" do
        Puppet::Indirector::Terminus.terminus_class(:file_content, :file).should equal(Puppet::Indirector::FileContent::File)
    end

    it "should be a subclass of the File terminus" do
        Puppet::Indirector::FileContent::File.superclass.should equal(Puppet::Indirector::File)
    end
end

describe Puppet::Indirector::FileContent::File, "when finding a single file" do
    before do
        @content = Puppet::Indirector::FileContent::File.new
        @path = "/my/file"
    end

    it "should return nil if the file does not exist"

    it "should return a Content instance with the path set to the file if the file exists"
end
