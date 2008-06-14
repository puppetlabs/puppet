#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/indirector/request'

describe Puppet::Indirector::Request do
    describe "when initializing" do
        it "should require an indirection name, a key, and a method" do
            lambda { Puppet::Indirector::Request.new }.should raise_error(ArgumentError)
        end

        it "should use provided value as the key if it is a string" do
            Puppet::Indirector::Request.new(:ind, :method, "mykey").key.should == "mykey"
        end

        it "should use provided value as the key if it is a symbol" do
            Puppet::Indirector::Request.new(:ind, :method, :mykey).key.should == :mykey
        end

        it "should use the name of the provided instance as its key if an instance is provided as the key instead of a string" do
            instance = mock 'instance', :name => "mykey"
            request = Puppet::Indirector::Request.new(:ind, :method, instance)
            request.key.should == "mykey"
            request.instance.should equal(instance)
        end

        it "should support options specified as a hash" do
            lambda { Puppet::Indirector::Request.new(:ind, :method, :key, :one => :two) }.should_not raise_error(ArgumentError)
        end

        it "should support nil options" do
            lambda { Puppet::Indirector::Request.new(:ind, :method, :key, nil) }.should_not raise_error(ArgumentError)
        end

        it "should support unspecified options" do
            lambda { Puppet::Indirector::Request.new(:ind, :method, :key) }.should_not raise_error(ArgumentError)
        end

        it "should fail if options are specified as anything other than nil or a hash" do
            lambda { Puppet::Indirector::Request.new(:ind, :method, :key, [:one, :two]) }.should raise_error(ArgumentError)
        end

        it "should use an empty options hash if nil was provided" do
            Puppet::Indirector::Request.new(:ind, :method, :key, nil).options.should == {}
        end

        it "should default to a nil node" do
            Puppet::Indirector::Request.new(:ind, :method, :key, nil).node.should be_nil
        end

        it "should set its node attribute if provided in the options" do
            Puppet::Indirector::Request.new(:ind, :method, :key, :node => "foo.com").node.should == "foo.com"
        end

        it "should default to a nil ip" do
            Puppet::Indirector::Request.new(:ind, :method, :key, nil).ip.should be_nil
        end

        it "should set its ip attribute if provided in the options" do
            Puppet::Indirector::Request.new(:ind, :method, :key, :ip => "192.168.0.1").ip.should == "192.168.0.1"
        end

        it "should default to being unauthenticated" do
            Puppet::Indirector::Request.new(:ind, :method, :key, nil).should_not be_authenticated
        end

        it "should set be marked authenticated if configured in the options" do
            Puppet::Indirector::Request.new(:ind, :method, :key, :authenticated => "eh").should be_authenticated
        end

        it "should keep its options as a hash even if a node is specified" do
            Puppet::Indirector::Request.new(:ind, :method, :key, :node => "eh").options.should be_instance_of(Hash)
        end

        it "should keep its options as a hash even if another option is specified" do
            Puppet::Indirector::Request.new(:ind, :method, :key, :foo => "bar").options.should be_instance_of(Hash)
        end
    end

    it "should look use the Indirection class to return the appropriate indirection" do
        ind = mock 'indirection'
        Puppet::Indirector::Indirection.expects(:instance).with(:myind).returns ind
        request = Puppet::Indirector::Request.new(:myind, :method, :key)

        request.indirection.should equal(ind)
    end
end
