#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/key/ca'

describe Puppet::SSL::Key::Ca do
  it "should have documentation" do
    Puppet::SSL::Key::Ca.doc.should be_instance_of(String)
  end

  it "should use the :privatekeydir as the collection directory" do
    Puppet.settings.expects(:value).with(:privatekeydir).returns "/key/dir"
    Puppet::SSL::Key::Ca.collection_directory.should == "/key/dir"
  end

  it "should store the ca key at the :cakey location" do
    Puppet.settings.stubs(:use)
    Puppet.settings.stubs(:value).returns "whatever"
    Puppet.settings.stubs(:value).with(:cakey).returns "/ca/key"
    file = Puppet::SSL::Key::Ca.new
    file.stubs(:ca?).returns true
    file.path("whatever").should == "/ca/key"
  end
end
