#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_serving/indirection_hooks'

describe Puppet::FileServing::IndirectionHooks, " when being used to select termini" do
    before do
        @object = Object.new
        @object.extend(Puppet::FileServing::IndirectionHooks)
    end

    it "should escape the key before parsing" do
        uri = stub 'uri', :scheme => "puppet", :host => "blah", :path => "/something"
        URI.expects(:escape).with("mykey").returns("http://myhost/blah")
        URI.expects(:parse).with("http://myhost/blah").returns(uri)
        @object.select_terminus("mykey")
    end

    it "should use the URI class to parse the key" do
        uri = stub 'uri', :scheme => "puppet", :host => "blah", :path => "/something"
        URI.expects(:parse).with("http://myhost/blah").returns(uri)
        @object.select_terminus("http://myhost/blah")
    end

    it "should choose :rest when the protocol is 'puppet'" do
        @object.select_terminus("puppet://host/module/file").should == :rest
    end

    it "should choose :file_server when the protocol is 'puppetmounts' and the mount name is not 'modules'" do
        modules = mock 'modules'
        @object.stubs(:terminus).with(:modules).returns(modules)
        modules.stubs(:find_module).returns(nil)

        @object.select_terminus("puppetmounts://host/notmodules/file").should == :file_server
    end

    it "should choose :file_server when no server name is provided, the process name is 'puppet', and the mount name is not 'modules'" do
        modules = mock 'modules'
        @object.stubs(:terminus).with(:modules).returns(modules)
        modules.stubs(:find_module).returns(nil)

        Puppet.settings.expects(:value).with(:name).returns("puppet")
        @object.select_terminus("puppet:///notmodules/file").should == :file_server
    end

    it "should choose :modules if it would normally choose :file_server but the mount name is 'modules'" do
        @object.select_terminus("puppetmounts://host/modules/mymod/file").should == :modules
    end

    it "should choose :modules it would normally choose :file_server but a module exists with the mount name" do
        modules = mock 'modules'

        @object.expects(:terminus).with(:modules).returns(modules)
        modules.expects(:find_module).with("mymod", nil).returns(:thing)

        @object.select_terminus("puppetmounts://host/mymod/file").should == :modules
    end

    it "should choose :rest when no server name is provided and the process name is not 'puppet'" do
        Puppet.settings.expects(:value).with(:name).returns("puppetd")
        @object.select_terminus("puppet:///module/file").should == :rest
    end

    it "should choose :file when the protocol is 'file'" do
        @object.select_terminus("file://host/module/file").should == :file
    end

    it "should choose :file when the URI is a normal path name" do
        @object.select_terminus("/module/file").should == :file
    end

    # This is so that we only choose modules over mounts, not file
    it "should choose :file when the protocol is 'file' and the fully qualified path starts with '/modules'" do
        @object.select_terminus("file://host/modules/file").should == :file
    end

    it "should fail when a protocol other than :puppet, :file, or :puppetmounts is used" do
        proc { @object.select_terminus("http:///module/file") }.should raise_error(ArgumentError)
    end
end

describe Puppet::FileServing::IndirectionHooks, " when looking for a module whose name matches the mount name" do
    before do
        @object = Object.new
        @object.extend(Puppet::FileServing::IndirectionHooks)

        @modules = mock 'modules'
        @object.stubs(:terminus).with(:modules).returns(@modules)
    end

    it "should use the modules terminus to look up the module" do
        @modules.expects(:find_module).with("mymod", nil)
        @object.select_terminus("puppetmounts://host/mymod/my/file")
    end

    it "should pass the node name to the modules terminus" do
        @modules.expects(:find_module).with("mymod", nil)
        @object.select_terminus("puppetmounts://host/mymod/my/file")
    end

    it "should log a deprecation warning if a module is found" do
        @modules.expects(:find_module).with("mymod", nil).returns(:something)
        Puppet.expects(:warning)
        @object.select_terminus("puppetmounts://host/mymod/my/file")
    end
end
