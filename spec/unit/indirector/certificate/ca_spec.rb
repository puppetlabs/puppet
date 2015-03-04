#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/certificate/ca'

describe Puppet::SSL::Certificate::Ca do
  it "should have documentation" do
    expect(Puppet::SSL::Certificate::Ca.doc).to be_instance_of(String)
  end

  it "should use the :signeddir as the collection directory" do
    Puppet[:signeddir] = File.expand_path("/cert/dir")
    expect(Puppet::SSL::Certificate::Ca.collection_directory).to eq(Puppet[:signeddir])
  end

  it "should store the ca certificate at the :cacert location" do
    Puppet.settings.stubs(:use)
    Puppet[:cacert] = File.expand_path("/ca/cert")
    file = Puppet::SSL::Certificate::Ca.new
    file.stubs(:ca?).returns true
    expect(file.path("whatever")).to eq(Puppet[:cacert])
  end
end
