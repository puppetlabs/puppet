#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/indirector/file_content/file_server'

describe Puppet::Indirector::FileContent::FileServer do
  it "should be registered with the file_content indirection" do
    Puppet::Indirector::Terminus.terminus_class(:file_content, :file_server).should equal(Puppet::Indirector::FileContent::FileServer)
  end

  it "should be a subclass of the FileServer terminus" do
    Puppet::Indirector::FileContent::FileServer.superclass.should equal(Puppet::Indirector::FileServer)
  end
end
