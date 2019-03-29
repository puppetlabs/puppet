require 'spec_helper'

require 'puppet/indirector/certificate/file'

describe Puppet::SSL::Certificate::File do
  it "should have documentation" do
    expect(Puppet::SSL::Certificate::File.doc).to be_instance_of(String)
  end

  it "should use the :certdir as the collection directory" do
    Puppet[:certdir] = File.expand_path("/cert/dir")
    expect(Puppet::SSL::Certificate::File.collection_directory).to eq(Puppet[:certdir])
  end

  it "should store the ca certificate at the :localcacert location" do
    allow(Puppet.settings).to receive(:use)
    Puppet[:localcacert] = File.expand_path("/ca/cert")
    file = Puppet::SSL::Certificate::File.new
    allow(file).to receive(:ca?).and_return(true)
    expect(file.path("whatever")).to eq(Puppet[:localcacert])
  end
end
