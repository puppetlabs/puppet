#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/certificate/file'

describe Puppet::SSL::Certificate::File do
  it "should have documentation" do
    Puppet::SSL::Certificate::File.doc.should be_instance_of(String)
  end

  it "should use the :certdir as the collection directory" do
    Puppet.settings.expects(:value).with(:certdir).returns "/cert/dir"
    Puppet::SSL::Certificate::File.collection_directory.should == "/cert/dir"
  end

  it "should store the ca certificate at the :localcacert location" do
    Puppet.settings.stubs(:use)
    Puppet.settings.stubs(:value).returns "whatever"
    Puppet.settings.stubs(:value).with(:localcacert).returns "/ca/cert"
    file = Puppet::SSL::Certificate::File.new
    file.stubs(:ca?).returns true
    file.path("whatever").should == "/ca/cert"
  end
end
