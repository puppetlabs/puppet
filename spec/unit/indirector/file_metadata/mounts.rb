#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/file_metadata/mounts'

describe Puppet::Indirector::FileMetadata::Mounts do
    it "should be registered with the file_metadata indirection" do
        Puppet::Indirector::Terminus.terminus_class(:file_metadata, :mounts).should equal(Puppet::Indirector::FileMetadata::Mounts)
    end

    it "should be a subclass of the FileServer terminus" do
        Puppet::Indirector::FileMetadata::Mounts.superclass.should equal(Puppet::Indirector::FileServer)
    end
end
