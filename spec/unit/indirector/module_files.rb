#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-19.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector/module_files'

module ModuleFilesTerminusTesting
    def setup
        Puppet::Indirector::Terminus.stubs(:register_terminus_class)
        @model = mock 'model'
        @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
        Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)

        @module_files_class = Class.new(Puppet::Indirector::ModuleFiles) do
            def self.to_s
                "Testing::Mytype"
            end
        end

        @module_files = @module_files_class.new

        @uri = "puppetmounts://host/modules/my/local/file"
        @module = Puppet::Module.new("mymod", "/module/path")
    end
end

describe Puppet::Indirector::ModuleFiles, " when finding files" do
    include ModuleFilesTerminusTesting

    it "should strip off the leading '/modules' mount name" do
        Puppet::Module.expects(:find).with('my', nil).returns @module
        @module_files.find(@uri)
    end

    it "should not strip off leading terms that start with '/modules' but are longer words" do
        Puppet::Module.expects(:find).with('modulestart', nil).returns nil
        @module_files.find("puppetmounts://host/modulestart/my/local/file")
    end

    it "should search for a module whose name is the first term in the remaining file path" do
        Puppet::Module.expects(:find).with('my', nil).returns @module
        @module_files.find(@uri)
    end

    it "should search for a file relative to the module's files directory" do
        Puppet::Module.expects(:find).with('my', nil).returns @module
        FileTest.expects(:exists?).with("/module/path/files/local/file")
        @module_files.find(@uri)
    end

    it "should return nil if the module does not exist" do
        Puppet::Module.expects(:find).with('my', nil).returns nil
        @module_files.find(@uri).should be_nil
    end

    it "should return nil if the module exists but the file does not" do
        Puppet::Module.expects(:find).with('my', nil).returns @module
        FileTest.expects(:exists?).with("/module/path/files/local/file").returns(false)
        @module_files.find(@uri).should be_nil
    end

    it "should return an instance of the model created with the full path if a module is found and the file exists" do
        Puppet::Module.expects(:find).with('my', nil).returns @module
        FileTest.expects(:exists?).with("/module/path/files/local/file").returns(true)
        @model.expects(:new).with("/module/path/files/local/file").returns(:myinstance)
        @module_files.find(@uri).should == :myinstance
    end

    it "should use the node's environment to look up the module if the node name is provided" do
        node = stub "node", :environment => "testing"
        Puppet::Node.expects(:find).with("mynode").returns(node)
        Puppet::Module.expects(:find).with('my', "testing")
        @module_files.find(@uri, :node => "mynode")
    end

    it "should use the local environment setting to look up the module if the node name is not provided and the environment is not set to ''" do
        Puppet.settings.stubs(:value).with(:environment).returns("testing")
        Puppet::Module.expects(:find).with('my', "testing")
        @module_files.find(@uri)
    end

    it "should not us an environment when looking up the module if the node name is not provided and the environment is set to ''" do
        Puppet.settings.stubs(:value).with(:environment).returns("")
        Puppet::Module.expects(:find).with('my', nil)
        @module_files.find(@uri)
    end
end

describe Puppet::Indirector::ModuleFiles, " when returning file paths" do
    it "should follow links if the links option is set to :follow"

    it "should ignore links if the links option is not set to follow"
end
