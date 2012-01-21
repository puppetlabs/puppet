#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/certificate/ca'

describe Puppet::SSL::Certificate::Ca do
  it "should have documentation" do
    Puppet::SSL::Certificate::Ca.doc.should be_instance_of(String)
  end

  it "should use the :signeddir as the collection directory" do
    Puppet.settings.expects(:value).with(:signeddir).returns "/cert/dir"
    Puppet::SSL::Certificate::Ca.collection_directory.should == "/cert/dir"
  end

  it "should store the ca certificate at the :cacert location" do
    Puppet.settings.stubs(:use)
    Puppet.settings.stubs(:value).returns "whatever"
    Puppet.settings.stubs(:value).with(:cacert).returns "/ca/cert"
    file = Puppet::SSL::Certificate::Ca.new
    file.stubs(:ca?).returns true
    file.path("whatever").should == "/ca/cert"
  end
end
