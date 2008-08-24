#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-19.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector/module_files'


describe Puppet::Indirector::ModuleFiles do

    before :each do
        Puppet::Node::Environment.stubs(:new).returns(stub('env', :name => "myenv"))
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
  
        @module = Puppet::Module.new("mymod", "/module/path")

        @request = Puppet::Indirector::Request.new(:mytype, :find, "puppet://host/modules/mymod/local/file")
    end

    describe Puppet::Indirector::ModuleFiles, " when finding files" do
        before do
            Puppet::Module.stubs(:find).returns @module
        end

        it "should strip off the leading 'modules/' mount name" do
            Puppet::Module.expects(:find).with { |key, env| key == 'mymod' }.returns @module
            @module_files.find(@request)
        end

        it "should not strip off leading terms that start with 'modules' but are longer words" do
            @request.stubs(:key).returns "modulestart/mymod/local/file"
            Puppet::Module.expects(:find).with { |key, env| key == 'modulestart'}.returns nil
            @module_files.find(@request)
        end

        it "should search for a module whose name is the first term in the remaining file path" do
            @module_files.find(@request)
        end

        it "should search for a file relative to the module's files directory" do
            FileTest.expects(:exists?).with("/module/path/files/local/file")
            @module_files.find(@request)
        end

        it "should return nil if the module does not exist" do
            Puppet::Module.expects(:find).returns nil
            @module_files.find(@request).should be_nil
        end

        it "should return nil if the module exists but the file does not" do
            FileTest.expects(:exists?).with("/module/path/files/local/file").returns(false)
            @module_files.find(@request).should be_nil
        end

        it "should return an instance of the model if a module is found and the file exists" do
            FileTest.expects(:exists?).with("/module/path/files/local/file").returns(true)
            @model.expects(:new).returns(:myinstance)
            @module_files.find(@request).should == :myinstance
        end

        it "should use the node's environment to look up the module if the node name is provided" do
            node = stub "node", :environment => "testing"
            Puppet::Node.expects(:find).with("mynode").returns(node)
            Puppet::Module.expects(:find).with('mymod', "testing")

            @request.stubs(:node).returns "mynode"
            @module_files.find(@request)
        end

        it "should use the default environment setting to look up the module if the node name is not provided" do
            env = stub "environment", :name => "testing"
            Puppet::Node::Environment.stubs(:new).returns(env)
            Puppet::Module.expects(:find).with('mymod', "testing")
            @module_files.find(@request)
        end
    end

    describe Puppet::Indirector::ModuleFiles, " when returning instances" do

        before do
            Puppet::Module.expects(:find).with('mymod', "myenv").returns @module
            FileTest.expects(:exists?).with("/module/path/files/local/file").returns(true)
            @instance = mock 'instance'
        end

        it "should create the instance with the key used to find the instance" do
            @model.expects(:new).with { |key, *options| key == @request.key }
            @module_files.find(@request)
        end

        it "should create the instance with the path at which the instance was found" do
            @model.expects(:new).with { |key, options| options[:path] == "/module/path/files/local/file" }
            @module_files.find(@request)
        end

        it "should set the provided :links setting on to the instance if one is provided" do
            @model.expects(:new).returns(@instance)
            @instance.expects(:links=).with(:mytest)

            @request.options[:links] = :mytest
            @module_files.find(@request)
        end

        it "should not set a :links value if no :links parameter is provided" do
            @model.expects(:new).returns(@instance)
            @module_files.find(@request)
        end
    end

    describe Puppet::Indirector::ModuleFiles, " when authorizing" do

        before do
            @configuration = mock 'configuration'
            Puppet::FileServing::Configuration.stubs(:create).returns(@configuration)
        end

        it "should have an authorization hook" do
            @module_files.should respond_to(:authorized?)
        end

        it "should deny the :destroy method" do
            @request.expects(:method).returns :destroy
            @module_files.authorized?(@request).should be_false
        end

        it "should deny the :save method" do
            @request.expects(:method).returns :save
            @module_files.authorized?(@request).should be_false
        end

        it "should use the file server configuration to determine authorization" do
            @configuration.expects(:authorized?)
            @module_files.authorized?(@request)
        end

        it "should use the path directly from the URI if it already includes /modules" do
            @request.expects(:key).returns "modules/my/file"
            @configuration.expects(:authorized?).with { |uri, *args| uri == "modules/my/file" }
            @module_files.authorized?(@request)
        end

        it "should add modules/ to the file path if it's not included in the URI" do
            @request.expects(:key).returns "my/file"
            @configuration.expects(:authorized?).with { |uri, *args| uri == "modules/my/file" }
            @module_files.authorized?(@request)
        end

        it "should pass the node name to the file server configuration" do
            @request.expects(:key).returns "my/file"
            @configuration.expects(:authorized?).with { |key, options| options[:node] == "mynode" }
            @request.stubs(:node).returns "mynode"
            @module_files.authorized?(@request)
        end

        it "should pass the IP address to the file server configuration" do
            @request.expects(:ip).returns "myip"
            @configuration.expects(:authorized?).with { |key, options| options[:ipaddress] == "myip" }
            @module_files.authorized?(@request)
        end

        it "should return false if the file server configuration denies authorization" do
            @configuration.expects(:authorized?).returns(false)
            @module_files.authorized?(@request).should be_false
        end

        it "should return true if the file server configuration approves authorization" do
            @configuration.expects(:authorized?).returns(true)
            @module_files.authorized?(@request).should be_true
        end
    end

    describe Puppet::Indirector::ModuleFiles, " when searching for files" do

        it "should strip off the leading 'modules/' mount name" do
            Puppet::Node::Environment.stubs(:new).returns(stub('env', :name => "myenv"))
            Puppet::Module.expects(:find).with { |key, env| key == 'mymod'}.returns @module
            @module_files.search(@request)
        end

        it "should not strip off leading terms that start with '/modules' but are longer words" do
            Puppet::Node::Environment.stubs(:new).returns(stub('env', :name => "myenv"))
            Puppet::Module.expects(:find).with('modulestart', "myenv").returns nil
            @request.stubs(:key).returns "modulestart/my/local/file"
            @module_files.search @request
        end

        it "should search for a module whose name is the first term in the remaining file path" do
            Puppet::Node::Environment.stubs(:new).returns(stub('env', :name => "myenv"))
            Puppet::Module.expects(:find).with('mymod', "myenv").returns @module
            @module_files.search(@request)
        end

        it "should search for a file relative to the module's files directory" do
            Puppet::Node::Environment.stubs(:new).returns(stub('env', :name => "myenv"))
            Puppet::Module.expects(:find).with('mymod', "myenv").returns @module
            FileTest.expects(:exists?).with("/module/path/files/local/file")
            @module_files.search(@request)
        end

        it "should return nil if the module does not exist" do
            Puppet::Node::Environment.stubs(:new).returns(stub('env', :name => "myenv"))
            Puppet::Module.expects(:find).with('mymod', "myenv").returns nil
            @module_files.search(@request).should be_nil
        end

        it "should return nil if the module exists but the file does not" do
            Puppet::Node::Environment.stubs(:new).returns(stub('env', :name => "myenv"))
            Puppet::Module.expects(:find).with('mymod', "myenv").returns @module
            FileTest.expects(:exists?).with("/module/path/files/local/file").returns(false)
            @module_files.search(@request).should be_nil
        end

        it "should use the node's environment to look up the module if the node name is provided" do
            node = stub "node", :environment => "testing"
            Puppet::Node.expects(:find).with("mynode").returns(node)
            Puppet::Module.expects(:find).with('mymod', "testing")
            @request.stubs(:node).returns "mynode"
            @module_files.search(@request)
        end

        it "should use the default environment setting to look up the module if the node name is not provided and the environment is not set to ''" do
            env = stub 'env', :name => "testing"
            Puppet::Node::Environment.stubs(:new).returns(env)
            Puppet::Module.expects(:find).with('mymod', "testing")
            @module_files.search(@request)
        end

        it "should use :path2instances from the terminus_helper to return instances if a module is found and the file exists" do
            Puppet::Node::Environment.stubs(:new).returns(stub('env', :name => "myenv"))
            Puppet::Module.expects(:find).with('mymod', "myenv").returns @module
            FileTest.expects(:exists?).with("/module/path/files/local/file").returns(true)
            @module_files.expects(:path2instances).with(@request, "/module/path/files/local/file")
            @module_files.search(@request)
        end

        it "should pass the request directly to :path2instances" do
            Puppet::Node::Environment.stubs(:new).returns(stub('env', :name => "myenv"))
            Puppet::Module.expects(:find).with('mymod', "myenv").returns @module
            FileTest.expects(:exists?).with("/module/path/files/local/file").returns(true)
            @module_files.expects(:path2instances).with(@request, "/module/path/files/local/file")
            @module_files.search(@request)
        end
    end
end
