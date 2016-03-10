#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/file_content/file_server'

describe Puppet::Indirector::FileContent::FileServer do
  it "should be registered with the file_content indirection" do
    expect(Puppet::Indirector::Terminus.terminus_class(:file_content, :file_server)).to equal(Puppet::Indirector::FileContent::FileServer)
  end

  it "should be a subclass of the FileServer terminus" do
    expect(Puppet::Indirector::FileContent::FileServer.superclass).to equal(Puppet::Indirector::FileServer)
  end
end
