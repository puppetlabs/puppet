#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/file_content/modules'

describe Puppet::Indirector::FileContent::Modules do
    it "should be registered with the file_content indirection" do
        Puppet::Indirector::Terminus.terminus_class(:file_content, :modules).should equal(Puppet::Indirector::FileContent::Modules)
    end

    it "should be a subclass of the ModuleFiles terminus" do
        Puppet::Indirector::FileContent::Modules.superclass.should equal(Puppet::Indirector::ModuleFiles)
    end
end
