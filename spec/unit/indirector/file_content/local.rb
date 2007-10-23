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
        Puppet::FileServing::Content.expects(:new).with("/my/local", :links => nil).returns(:mycontent)
        @content.find(@uri).should == :mycontent
    end

    it "should pass the :links setting on to the created Content instance if the file exists" do
        @content = Puppet::Indirector::FileContent::Local.new
        @uri = "file:///my/local"

        FileTest.expects(:exists?).with("/my/local").returns true
        Puppet::FileServing::Content.expects(:new).with("/my/local", :links => :manage).returns(:mycontent)
        @content.find(@uri, :links => :manage)
    end

    it "should return nil if the file does not exist" do
        @content = Puppet::Indirector::FileContent::Local.new
        @uri = "file:///my/local"

        FileTest.expects(:exists?).with("/my/local").returns false
        @content.find(@uri).should be_nil
    end
end

describe Puppet::Indirector::FileContent::Local, "when searching for multiple files" do
    before do
        @content = Puppet::Indirector::FileContent::Local.new
        @uri = "file:///my/local"
    end

    it "should return nil if the file does not exist" do
        FileTest.expects(:exists?).with("/my/local").returns false
        @content.find(@uri).should be_nil
    end

    it "should use :path2instances from the terminus_helper to return instances if the file exists" do
        FileTest.expects(:exists?).with("/my/local").returns true
        @content.expects(:path2instances).with("/my/local", {})
        @content.search(@uri)
    end

    it "should pass any options on to :path2instances" do
        FileTest.expects(:exists?).with("/my/local").returns true
        @content.expects(:path2instances).with("/my/local", :testing => :one, :other => :two)
        @content.search(@uri, :testing => :one, :other => :two)
    end
end
