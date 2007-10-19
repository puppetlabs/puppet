#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-19.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector/file_server'
require 'puppet/file_serving/configuration'

module FileServerTerminusTesting
    def setup
        Puppet::Indirector::Terminus.stubs(:register_terminus_class)
        @model = mock 'model'
        @indirection = stub 'indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model
        Puppet::Indirector::Indirection.stubs(:instance).returns(@indirection)

        @file_server_class = Class.new(Puppet::Indirector::FileServer) do
            def self.to_s
                "Testing::Mytype"
            end
        end

        @file_server = @file_server_class.new

        @uri = "puppetmounts://host/my/local/file"
        @configuration = mock 'configuration'
        Puppet::FileServing::Configuration.stubs(:create).returns(@configuration)

        @module_server = mock 'module_server'
        @indirection.stubs(:terminus).with(:modules).returns(@module_server)
    end
end

describe Puppet::Indirector::FileServer, " when finding files" do
    include FileServerTerminusTesting

    it "should see if the modules terminus has the file" do
        @module_server.expects(:find).with(@uri, {})
        @configuration.stubs(:file_path)
        @file_server.find(@uri)
    end

    it "should pass the client name to the modules terminus if one is provided" do
        @module_server.expects(:find).with(@uri, :node => "mynode")
        @configuration.stubs(:file_path)
        @file_server.find(@uri, :node => "mynode")
    end

    it "should return any results from the modules terminus" do
        @module_server.expects(:find).with(@uri, {}).returns(:myinstance)
        @file_server.find(@uri).should == :myinstance
    end

    it "should produce a deprecation notice if it finds a file in the module terminus" do
        @module_server.expects(:find).with(@uri, {}).returns(:myinstance)
        Puppet.expects(:warning)
        @file_server.find(@uri)
    end

    it "should use the path portion of the URI as the file name" do
        @configuration.expects(:file_path).with("/my/local/file", :node => nil)
        @module_server.stubs(:find).returns(nil)
        @file_server.find(@uri)
    end

    it "should use the FileServing configuration to convert the file name to a fully qualified path" do
        @configuration.expects(:file_path).with("/my/local/file", :node => nil)
        @module_server.stubs(:find).returns(nil)
        @file_server.find(@uri)
    end

    it "should pass the node name to the FileServing configuration if one is provided" do
        @configuration.expects(:file_path).with("/my/local/file", :node => "testing")
        @module_server.stubs(:find)
        @file_server.find(@uri, :node => "testing")
    end

    it "should return nil if no fully qualified path is found" do
        @configuration.expects(:file_path).with("/my/local/file", :node => nil).returns(nil)
        @module_server.stubs(:find).returns(nil)
        @file_server.find(@uri).should be_nil
    end

    it "should return nil if the configuration returns a file path that does not exist" do
        @configuration.expects(:file_path).with("/my/local/file", :node => nil).returns("/some/file")
        FileTest.expects(:exists?).with("/some/file").returns(false)
        @module_server.stubs(:find).returns(nil)
        @file_server.find(@uri).should be_nil
    end

    it "should return an instance of the model created with the full path if a file is found and it exists" do
        @configuration.expects(:file_path).with("/my/local/file", :node => nil).returns("/some/file")
        FileTest.expects(:exists?).with("/some/file").returns(true)
        @module_server.stubs(:find).returns(nil)
        @model.expects(:new).with("/some/file").returns(:myinstance)
        @file_server.find(@uri).should == :myinstance
    end
end


describe Puppet::Indirector::FileServer, " when returning file paths" do
    it "should follow links if the links option is set to :follow"

    it "should ignore links if the links option is not set to follow"
end
