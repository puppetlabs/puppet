#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Type.type(:filebucket) do
    it "be local by default" do
        bucket = Puppet::Type.type(:filebucket).new :name => "main"

        bucket.name.should == "main"
        bucket.bucket.should be_instance_of(Puppet::Network::Client::Dipper)
        bucket.bucket.local.should == true
    end

    it "not be local if path is false" do
        bucket = Puppet::Type.type(:filebucket).new :name => "main", :path => false

        bucket.name.should == "main"
        bucket.bucket.should be_instance_of(Puppet::Network::Client::Dipper)
        bucket.bucket.local.should_not == true
    end

    it "not be local if a server is specified" do
        bucket = Puppet::Type.type(:filebucket).new :name => "main", :server => "puppet"

        bucket.name.should == "main"
        bucket.bucket.should be_instance_of(Puppet::Network::Client::Dipper)
        bucket.bucket.local.should_not == true
    end

end
