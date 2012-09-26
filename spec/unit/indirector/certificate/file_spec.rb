#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/certificate/file'

describe Puppet::SSL::Certificate::File do
  it "should have documentation" do
    Puppet::SSL::Certificate::File.doc.should be_instance_of(String)
  end

  it "should use the :certdir as the collection directory" do
    Puppet[:certdir] = File.expand_path("/cert/dir")
    Puppet::SSL::Certificate::File.collection_directory.should == Puppet[:certdir]
  end

  it "should store the ca certificate at the :localcacert location" do
    Puppet.settings.stubs(:use)
    Puppet[:localcacert] = File.expand_path("/ca/cert")
    file = Puppet::SSL::Certificate::File.new
    file.stubs(:ca?).returns true
    file.path("whatever").should == Puppet[:localcacert]
  end
end
