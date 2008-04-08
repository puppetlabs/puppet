#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/indirector/request'

describe Puppet::Indirector::Request do
    describe "when initializing" do
        it "should require an indirection name, a key, and a method" do
            lambda { Puppet::Indirector::Request.new }.should raise_error(ArgumentError)
        end

        it "should support options specified as a hash" do
            lambda { Puppet::Indirector::Request.new(:ind, :key, :method, :one => :two) }.should_not raise_error(ArgumentError)
        end

        it "should support nil options" do
            lambda { Puppet::Indirector::Request.new(:ind, :key, :method, nil) }.should_not raise_error(ArgumentError)
        end

        it "should support unspecified options" do
            lambda { Puppet::Indirector::Request.new(:ind, :key, :method) }.should_not raise_error(ArgumentError)
        end

        it "should fail if options are specified as anything other than nil or a hash" do
            lambda { Puppet::Indirector::Request.new(:ind, :key, :method, [:one, :two]) }.should raise_error(ArgumentError)
        end

        it "should use an empty options hash if nil was provided" do
            Puppet::Indirector::Request.new(:ind, :key, :method, nil).options.should == {}
        end
    end

    it "should look use the Indirection class to return the appropriate indirection" do
        ind = mock 'indirection'
        Puppet::Indirector::Indirection.expects(:instance).with(:myind).returns ind
        request = Puppet::Indirector::Request.new(:myind, :key, :method)

        request.indirection.should equal(ind)
    end
end
