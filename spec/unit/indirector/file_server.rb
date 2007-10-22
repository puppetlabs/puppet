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

describe Puppet::Indirector::FileServer, " when checking authorization" do
    include FileServerTerminusTesting

    it "should have an authorization hook" do
        @file_server.should respond_to(:authorized?)
    end

    it "should deny the :destroy method" do
        @file_server.authorized?(:destroy, "whatever").should be_false
    end

    it "should deny the :save method" do
        @file_server.authorized?(:save, "whatever").should be_false
    end

    it "should use the file server configuration to determine authorization" do
        @configuration.expects(:authorized?)
        @file_server.authorized?(:find, "puppetmounts://host/my/file")
    end

    it "should pass the file path from the URI to the file server configuration" do
        @configuration.expects(:authorized?).with { |uri, *args| uri == "/my/file" }
        @file_server.authorized?(:find, "puppetmounts://host/my/file")
    end

    it "should pass the node name to the file server configuration" do
        @configuration.expects(:authorized?).with { |key, options| options[:node] == "mynode" }
        @file_server.authorized?(:find, "puppetmounts://host/my/file", :node => "mynode")
    end

    it "should pass the IP address to the file server configuration" do
        @configuration.expects(:authorized?).with { |key, options| options[:ipaddress] == "myip" }
        @file_server.authorized?(:find, "puppetmounts://host/my/file", :ipaddress => "myip")
    end

    it "should return false if the file server configuration denies authorization" do
        @configuration.expects(:authorized?).returns(false)
        @file_server.authorized?(:find, "puppetmounts://host/my/file").should be_false
    end

    it "should return true if the file server configuration approves authorization" do
        @configuration.expects(:authorized?).returns(true)
        @file_server.authorized?(:find, "puppetmounts://host/my/file").should be_true
    end
end
