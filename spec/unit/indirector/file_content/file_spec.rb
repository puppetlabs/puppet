#!/usr/bin/env rspec
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

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
