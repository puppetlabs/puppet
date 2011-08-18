#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/file_content/file'

describe Puppet::Indirector::FileContent::File do
  it "should be registered with the file_content indirection" do
    Puppet::Indirector::Terminus.terminus_class(:file_content, :file).should equal(Puppet::Indirector::FileContent::File)
  end

  it "should be a subclass of the DirectFileServer terminus" do
    Puppet::Indirector::FileContent::File.superclass.should equal(Puppet::Indirector::DirectFileServer)
  end
end
