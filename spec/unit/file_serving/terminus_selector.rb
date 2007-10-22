#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/file_serving/terminus_selector'

describe Puppet::FileServing::TerminusSelector, " when being used to select termini" do
    before do
        @object = Object.new
        @object.extend(Puppet::FileServing::TerminusSelector)
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

    it "should choose :modules when the protocol is 'puppetmounts' and the mount name is 'modules'" do
        @object.select_terminus("puppetmounts://host/modules/mymod/file").should == :modules
    end

    it "should choose :modules when no server name is provided, the process name is 'puppet', and the mount name is 'modules'" do
        Puppet.settings.expects(:value).with(:name).returns("puppet")
        @object.select_terminus("puppet:///modules/mymod/file").should == :modules
    end

    it "should choose :mounts when the protocol is 'puppetmounts' and the mount name is not 'modules'" do
        @object.select_terminus("puppetmounts://host/notmodules/file").should == :mounts
    end

    it "should choose :mounts when no server name is provided, the process name is 'puppet', and the mount name is not 'modules'" do
        Puppet.settings.expects(:value).with(:name).returns("puppet")
        @object.select_terminus("puppet:///notmodules/file").should == :mounts
    end

    it "should choose :rest when no server name is provided and the process name is not 'puppet'" do
        Puppet.settings.expects(:value).with(:name).returns("puppetd")
        @object.select_terminus("puppet:///module/file").should == :rest
    end

    it "should choose :local when the protocol is 'file'" do
        @object.select_terminus("file://host/module/file").should == :local
    end

    it "should choose :local when the URI is a normal path name" do
        @object.select_terminus("/module/file").should == :local
    end

    # This is so that we only choose modules over mounts, not local
    it "should choose :local when the protocol is 'file' and the fully qualified path starts with '/modules'" do
        @object.select_terminus("file://host/modules/file").should == :local
    end

    it "should fail when a protocol other than :puppet, :file, or :puppetmounts is used" do
        proc { @object.select_terminus("http:///module/file") }.should raise_error(ArgumentError)
    end
end
