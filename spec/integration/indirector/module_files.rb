#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-19.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector/file_content/modules'
require 'puppet/indirector/module_files'

describe Puppet::Indirector::ModuleFiles, " when interacting with Puppet::Module and FileServing::Content" do
    it "should look for files in the module's 'files' directory" do
        @environment = stub('env', :name => "myenv")
        Puppet::Node::Environment.stubs(:new).returns(@environment)
        # We just test a subclass, since it's close enough.
        @terminus = Puppet::Indirector::FileContent::Modules.new
        @module = Puppet::Module.new("mymod", "/some/path/mymod")

        @environment.expects(:module).with("mymod").returns @module

        filepath = "/some/path/mymod/files/myfile"

        FileTest.expects(:exists?).with(filepath).returns(true)

        @request = Puppet::Indirector::Request.new(:content, :find, "puppet://host/modules/mymod/myfile")

        @terminus.find(@request).should be_instance_of(Puppet::FileServing::Content)
    end
end

describe Puppet::Indirector::ModuleFiles, " when interacting with FileServing::Fileset and FileServing::Content" do
    it "should return an instance for every file in the fileset" do
        @environment = stub('env', :name => "myenv")
        Puppet::Node::Environment.stubs(:new).returns @environment
        @terminus = Puppet::Indirector::FileContent::Modules.new

        @path = Tempfile.new("module_file_testing")
        path = @path.path
        @path.close!
        @path = path

        Dir.mkdir(@path)
        Dir.mkdir(File.join(@path, "files"))

        basedir = File.join(@path, "files", "myfile")
        Dir.mkdir(basedir)

        File.open(File.join(basedir, "one"), "w") { |f| f.print "one content" }
        File.open(File.join(basedir, "two"), "w") { |f| f.print "two content" }

        @module = Puppet::Module.new("mymod", @path)
        @environment.expects(:module).with("mymod").returns @module

        @request = Puppet::Indirector::Request.new(:content, :search, "puppet://host/modules/mymod/myfile", :recurse => true)

        result = @terminus.search(@request)
        result.should be_instance_of(Array)
        result.length.should == 3
        result.each { |r| r.should be_instance_of(Puppet::FileServing::Content) }
    end
end
