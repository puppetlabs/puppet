#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/key/ca'

describe Puppet::SSL::Key::Ca do
  it "should have documentation" do
    Puppet::SSL::Key::Ca.doc.should be_instance_of(String)
  end

  it "should use the :privatekeydir as the collection directory" do
    Puppet[:privatekeydir] = "/key/dir"
    Puppet::SSL::Key::Ca.collection_directory.should == Puppet[:privatekeydir]
  end

  it "should store the ca key at the :cakey location" do
    Puppet.settings.stubs(:use)
    Puppet[:cakey] = "/ca/key"
    file = Puppet::SSL::Key::Ca.new
    file.stubs(:ca?).returns true
    file.path("whatever").should == Puppet[:cakey]
  end
end
