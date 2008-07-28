#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/format'

describe Puppet::Network::Format do
    it "should require a name" do
        lambda { Puppet::Network::Format.new }.should raise_error(ArgumentError)
    end

    it "should be able to provide its name" do
        Puppet::Network::Format.new(:my_format).name.should == :my_format
    end

    it "should be able to set its mime type at initialization" do
        format = Puppet::Network::Format.new(:my_format, :mime => "foo/bar")
        format.mime.should == "foo/bar"
    end

    it "should default to text plus the name of the format as the mime type" do
        Puppet::Network::Format.new(:my_format).mime.should == "text/my_format"
    end

    it "should fail if unsupported options are provided" do
        lambda { Puppet::Network::Format.new(:my_format, :foo => "bar") }.should raise_error(ArgumentError)
    end

    it "should support being confined" do
        Puppet::Network::Format.new(:my_format).should respond_to(:confine)
    end

    it "should not be considered suitable if confinement conditions are not met" do
        format = Puppet::Network::Format.new(:my_format)
        format.confine :true => false
        format.should_not be_suitable
    end
end
