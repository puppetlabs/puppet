#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_serving/indirection_hooks'

describe Puppet::FileServing::IndirectionHooks do
    before do
        @object = Object.new
        @object.extend(Puppet::FileServing::IndirectionHooks)

        @request = stub 'request', :key => "http://myhost/blah", :options => {:node => "whatever"}
    end

    describe "when being used to select termini" do
        it "should escape the key before parsing" do
            uri = stub 'uri', :scheme => "puppet", :host => "blah", :path => "/something"
            URI.expects(:escape).with("http://myhost/blah").returns("escaped_blah")
            URI.expects(:parse).with("escaped_blah").returns(uri)
            @object.select_terminus(@request)
        end

        it "should use the URI class to parse the key" do
            uri = stub 'uri', :scheme => "puppet", :host => "blah", :path => "/something"
            URI.expects(:parse).with("http://myhost/blah").returns(uri)
            @object.select_terminus @request
        end

        it "should choose :rest when the protocol is 'puppet'" do
            @request.stubs(:key).returns "puppet://host/module/file"
            @object.select_terminus(@request).should == :rest
        end

        it "should choose :file_server when the protocol is 'puppetmounts' and the mount name is not 'modules'" do
            modules = mock 'modules'
            @object.stubs(:terminus).with(:modules).returns(modules)
            modules.stubs(:find_module).returns(nil)

            @request.stubs(:key).returns "puppetmounts://host/notmodules/file"

            @object.select_terminus(@request).should == :file_server
        end

        it "should choose :file_server when no server name is provided, the process name is 'puppet', and the mount name is not 'modules'" do
            modules = mock 'modules'
            @object.stubs(:terminus).with(:modules).returns(modules)
            modules.stubs(:find_module).returns(nil)

            Puppet.settings.expects(:value).with(:name).returns("puppet")
            @request.stubs(:key).returns "puppet:///notmodules/file"
            @object.select_terminus(@request).should == :file_server
        end

        it "should choose :modules if it would normally choose :file_server but the mount name is 'modules'" do
            @request.stubs(:key).returns "puppetmounts://host/modules/mymod/file"
            @object.select_terminus(@request).should == :modules
        end

        it "should choose :modules if it would normally choose :file_server but a module exists with the mount name" do
            modules = mock 'modules'

            @object.expects(:terminus).with(:modules).returns(modules)
            modules.expects(:find_module).with("mymod", @request.options[:node]).returns(:thing)

            @request.stubs(:key).returns "puppetmounts://host/mymod/file"
            @object.select_terminus(@request).should == :modules
        end

        it "should choose :rest when no server name is provided and the process name is not 'puppet'" do
            Puppet.settings.expects(:value).with(:name).returns("puppetd")
            @request.stubs(:key).returns "puppet:///module/file"
            @object.select_terminus(@request).should == :rest
        end

        it "should choose :file when the protocol is 'file'" do
            @request.stubs(:key).returns "file://host/module/file"
            @object.select_terminus(@request).should == :file
        end

        it "should choose :file when the URI is a normal path name" do
            @request.stubs(:key).returns "/module/file"
            @object.select_terminus(@request).should == :file
        end

        # This is so that we only choose modules over mounts, not file
        it "should choose :file when the protocol is 'file' and the fully qualified path starts with '/modules'" do
            @request.stubs(:key).returns "/module/file"
            @object.select_terminus(@request).should == :file
        end

        it "should fail when a protocol other than :puppet, :file, or :puppetmounts is used" do
            @request.stubs(:key).returns "http:///module/file"
            proc { @object.select_terminus(@request) }.should raise_error(ArgumentError)
        end
    end

    describe "when looking for a module whose name matches the mount name" do
        before do
            @modules = mock 'modules'
            @object.stubs(:terminus).with(:modules).returns(@modules)

            @request.stubs(:key).returns "puppetmounts://host/mymod/file"
        end

        it "should use the modules terminus to look up the module" do
            @modules.expects(:find_module).with("mymod", @request.options[:node])
            @object.select_terminus @request
        end

        it "should pass the node name to the modules terminus" do
            @modules.expects(:find_module).with("mymod", @request.options[:node])
            @object.select_terminus @request
        end

        it "should log a deprecation warning if a module is found" do
            @modules.expects(:find_module).with("mymod", @request.options[:node]).returns(:something)
            Puppet.expects(:warning)
            @object.select_terminus @request
        end
    end
end
