#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-19.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector/file_content/modules'
require 'puppet/indirector/module_files'

describe Puppet::Indirector::ModuleFiles, " when interacting with Puppet::Module and FileServing::Content" do
    it "should look for files in the module's 'files' directory" do
        Puppet::Node::Environment.stubs(:new).returns(stub('env', :name => "myenv"))
        # We just test a subclass, since it's close enough.
        @terminus = Puppet::Indirector::FileContent::Modules.new
        @module = Puppet::Module.new("mymod", "/some/path/mymod")
        Puppet::Module.expects(:find).with("mymod", "myenv").returns(@module)

        filepath = "/some/path/mymod/files/myfile"

        FileTest.expects(:exists?).with(filepath).returns(true)

        @request = Puppet::Indirector::Request.new(:content, :find, "puppetmounts://host/modules/mymod/myfile")

        @terminus.find(@request).should be_instance_of(Puppet::FileServing::Content)
    end
end

describe Puppet::Indirector::ModuleFiles, " when interacting with FileServing::Fileset and FileServing::Content" do
    it "should return an instance for every file in the fileset" do
        Puppet::Node::Environment.stubs(:new).returns(stub('env', :name => "myenv"))
        @terminus = Puppet::Indirector::FileContent::Modules.new
        @module = Puppet::Module.new("mymod", "/some/path/mymod")
        Puppet::Module.expects(:find).with("mymod", "myenv").returns(@module)

        filepath = "/some/path/mymod/files/myfile"
        FileTest.stubs(:exists?).with(filepath).returns(true)

        stat = stub 'stat', :directory? => true
        File.stubs(:lstat).with(filepath).returns(stat)

        subfiles = %w{one two}
        subfiles.each do |f|
            path = File.join(filepath, f)
            FileTest.stubs(:exists?).with(path).returns(true)
        end

        Dir.expects(:entries).with(filepath).returns(%w{one two})

        @request = Puppet::Indirector::Request.new(:content, :search, "puppetmounts://host/modules/mymod/myfile", :recurse => true)

        result = @terminus.search(@request)
        result.should be_instance_of(Array)
        result.length.should == 3
        result.each { |r| r.should be_instance_of(Puppet::FileServing::Content) }
    end
end
