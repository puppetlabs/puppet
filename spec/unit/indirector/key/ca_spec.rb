#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/key/ca'

describe Puppet::SSL::Key::Ca do
  it "should have documentation" do
    expect(Puppet::SSL::Key::Ca.doc).to be_instance_of(String)
  end

  it "should use the :privatekeydir as the collection directory" do
    Puppet[:privatekeydir] = "/key/dir"
    expect(Puppet::SSL::Key::Ca.collection_directory).to eq(Puppet[:privatekeydir])
  end

  it "should store the ca key at the :cakey location" do
    Puppet.settings.stubs(:use)
    Puppet[:cakey] = "/ca/key"
    file = Puppet::SSL::Key::Ca.new
    file.stubs(:ca?).returns true
    expect(file.path("whatever")).to eq(Puppet[:cakey])
  end
end
