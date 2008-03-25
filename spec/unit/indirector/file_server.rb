#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-19.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector/file_server'
require 'puppet/file_serving/configuration'

describe Puppet::Indirector::FileServer do

    before :each do
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
    end

    describe Puppet::Indirector::FileServer, " when finding files" do

        it "should use the path portion of the URI as the file name" do
            @configuration.expects(:file_path).with("/my/local/file", :node => nil)
            @file_server.find(@uri)
        end

        it "should use the FileServing configuration to convert the file name to a fully qualified path" do
            @configuration.expects(:file_path).with("/my/local/file", :node => nil)
            @file_server.find(@uri)
        end

        it "should pass the node name to the FileServing configuration if one is provided" do
            @configuration.expects(:file_path).with("/my/local/file", :node => "testing")
            @file_server.find(@uri, :node => "testing")
        end

        it "should return nil if no fully qualified path is found" do
            @configuration.expects(:file_path).with("/my/local/file", :node => nil).returns(nil)
            @file_server.find(@uri).should be_nil
        end

        it "should return an instance of the model created with the full path if a file is found" do
            @configuration.expects(:file_path).with("/my/local/file", :node => nil).returns("/some/file")
            @model.expects(:new).returns(:myinstance)
            @file_server.find(@uri).should == :myinstance
        end
    end

    describe Puppet::Indirector::FileServer, " when returning instances" do
        before :each do
            @configuration.expects(:file_path).with("/my/local/file", :node => nil).returns("/some/file")
            @instance = mock 'instance'
        end

        it "should create the instance with the key used to find the instance" do
            @model.expects(:new).with { |key, *options| key == @uri }
            @file_server.find(@uri)
        end

        it "should create the instance with the path at which the instance was found" do
            @model.expects(:new).with { |key, options| options[:path] == "/some/file" }
            @file_server.find(@uri)
        end

        it "should set the provided :links setting on to the instance if one is provided" do
            @model.expects(:new).returns(@instance)
            @instance.expects(:links=).with(:mytest)
            @file_server.find(@uri, :links => :mytest)
        end

        it "should not set a :links value if no :links parameter is provided" do
            @model.expects(:new).returns(@instance)
            @file_server.find(@uri)
        end
    end

    describe Puppet::Indirector::FileServer, " when checking authorization" do

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

    describe Puppet::Indirector::FileServer, " when searching for files" do

        it "should use the path portion of the URI as the file name" do
            @configuration.expects(:file_path).with("/my/local/file", :node => nil)
            @file_server.search(@uri)
        end

        it "should use the FileServing configuration to convert the file name to a fully qualified path" do
            @configuration.expects(:file_path).with("/my/local/file", :node => nil)
            @file_server.search(@uri)
        end

        it "should pass the node name to the FileServing configuration if one is provided" do
            @configuration.expects(:file_path).with("/my/local/file", :node => "testing")
            @file_server.search(@uri, :node => "testing")
        end

        it "should return nil if no fully qualified path is found" do
            @configuration.expects(:file_path).with("/my/local/file", :node => nil).returns(nil)
            @file_server.search(@uri).should be_nil
        end

        it "should use :path2instances from the terminus_helper to return instances if a module is found and the file exists" do
            @configuration.expects(:file_path).with("/my/local/file", :node => nil).returns("/my/file")
            @file_server.expects(:path2instances).with(@uri, "/my/file", {})
            @file_server.search(@uri)
        end

        it "should pass any options on to :path2instances" do
            @configuration.expects(:file_path).with("/my/local/file", :node => nil).returns("/my/file")
            @file_server.expects(:path2instances).with(@uri, "/my/file", :testing => :one, :other => :two)
            @file_server.search(@uri, :testing => :one, :other => :two)
        end
    end
end
