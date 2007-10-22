#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/file_content/mounts'

describe Puppet::Indirector::FileContent::Mounts do
    it "should be registered with the file_content indirection" do
        Puppet::Indirector::Terminus.terminus_class(:file_content, :mounts).should equal(Puppet::Indirector::FileContent::Mounts)
    end

    it "should be a subclass of the FileServer terminus" do
        Puppet::Indirector::FileContent::Mounts.superclass.should equal(Puppet::Indirector::FileServer)
    end
end
