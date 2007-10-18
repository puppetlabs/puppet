#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/file_metadata/local'

describe Puppet::Indirector::FileMetadata::Local do
    it "should be registered with the file_metadata indirection" do
        Puppet::Indirector::Terminus.terminus_class(:file_metadata, :local).should equal(Puppet::Indirector::FileMetadata::Local)
    end
end
