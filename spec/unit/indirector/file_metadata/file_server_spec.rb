#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/file_metadata/file_server'

describe Puppet::Indirector::FileMetadata::FileServer do
  it "should be registered with the file_metadata indirection" do
    expect(Puppet::Indirector::Terminus.terminus_class(:file_metadata, :file_server)).to equal(Puppet::Indirector::FileMetadata::FileServer)
  end

  it "should be a subclass of the FileServer terminus" do
    expect(Puppet::Indirector::FileMetadata::FileServer.superclass).to equal(Puppet::Indirector::FileServer)
  end
end
