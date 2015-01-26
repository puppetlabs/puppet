#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/indirector/file_content/file'

describe Puppet::Indirector::FileContent::File do
  it "should be registered with the file_content indirection" do
    expect(Puppet::Indirector::Terminus.terminus_class(:file_content, :file)).to equal(Puppet::Indirector::FileContent::File)
  end

  it "should be a subclass of the DirectFileServer terminus" do
    expect(Puppet::Indirector::FileContent::File.superclass).to equal(Puppet::Indirector::DirectFileServer)
  end
end
