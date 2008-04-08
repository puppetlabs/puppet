#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-19.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector/file_content/file'
require 'puppet/indirector/module_files'

describe Puppet::Indirector::DirectFileServer, " when interacting with the filesystem and the model" do
    before do
        # We just test a subclass, since it's close enough.
        @terminus = Puppet::Indirector::FileContent::File.new

        @filepath = "/path/to/my/file"
    end

    it "should return an instance of the model" do
        FileTest.expects(:exists?).with(@filepath).returns(true)

        @terminus.find(@terminus.indirection.request(:find, "file://host#{@filepath}")).should be_instance_of(Puppet::FileServing::Content)
    end

    it "should return an instance capable of returning its content" do
        FileTest.expects(:exists?).with(@filepath).returns(true)
        File.stubs(:lstat).with(@filepath).returns(stub("stat", :ftype => "file"))
        File.expects(:read).with(@filepath).returns("my content")

        instance = @terminus.find(@terminus.indirection.request(:find, "file://host#{@filepath}"))

        instance.content.should == "my content"
    end
end

describe Puppet::Indirector::DirectFileServer, " when interacting with FileServing::Fileset and the model" do
    before do
        @terminus = Puppet::Indirector::FileContent::File.new

        @filepath = "/my/file"
        FileTest.stubs(:exists?).with(@filepath).returns(true)

        stat = stub 'stat', :directory? => true
        File.stubs(:lstat).with(@filepath).returns(stat)

        @subfiles = %w{one two}
        @subfiles.each do |f|
            path = File.join(@filepath, f)
            FileTest.stubs(:exists?).with(@path).returns(true)
        end

        Dir.expects(:entries).with(@filepath).returns @subfiles

        @request = @terminus.indirection.request(:search, "file:///my/file", :recurse => true)
    end

    it "should return an instance for every file in the fileset" do
        result = @terminus.search(@request)
        result.should be_instance_of(Array)
        result.length.should == 3
        result.each { |r| r.should be_instance_of(Puppet::FileServing::Content) }
    end

    it "should return instances capable of returning their content" do
        @subfiles.each do |name|
            File.stubs(:lstat).with(File.join(@filepath, name)).returns stub("#{name} stat", :ftype => "file", :directory? => false)
            File.expects(:read).with(File.join(@filepath, name)).returns("#{name} content")
        end

        @terminus.search(@request).each do |instance|
            case instance.key
            when /one/: instance.content.should == "one content"
            when /two/: instance.content.should == "two content"
            when /\.$/: 
            else
                raise "No valid key for %s" % instance.key.inspect
            end
        end
    end
end
