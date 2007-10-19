#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/util/uri_helper'

describe Puppet::Util::URIHelper, " when converting a key to a URI" do
    before do
        @helper = Object.new
        @helper.extend(Puppet::Util::URIHelper)
    end

    it "should return the URI instance" do
        URI.expects(:parse).with("file:///myhost/blah").returns(:myuri)
        @helper.key2uri("/myhost/blah").should == :myuri
    end

    it "should escape the key before parsing" do
        URI.expects(:escape).with("mykey").returns("http://myhost/blah")
        URI.expects(:parse).with("http://myhost/blah").returns(:myuri)
        @helper.key2uri("mykey").should == :myuri
    end

    it "should use the URI class to parse the key" do
        URI.expects(:parse).with("http://myhost/blah").returns(:myuri)
        @helper.key2uri("http://myhost/blah").should == :myuri
    end

    it "should set the scheme to 'file' if the key is a fully qualified path" do
        URI.expects(:parse).with("file:///myhost/blah").returns(:myuri)
        @helper.key2uri("/myhost/blah").should == :myuri
    end

    it "should set the host to 'nil' if the key is a fully qualified path" do
        URI.expects(:parse).with("file:///myhost/blah").returns(:myuri)
        @helper.key2uri("/myhost/blah").should == :myuri
    end
end
