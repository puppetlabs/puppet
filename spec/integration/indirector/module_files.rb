#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-19.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/indirector/file_metadata/modules'
require 'puppet/indirector/module_files'

describe Puppet::Indirector::ModuleFiles, " when interacting with Puppet::Module" do
    it "should look for files in the module's 'files' directory" do
        # We just test a subclass, since it's close enough.
        @terminus = Puppet::Indirector::FileMetadata::Modules.new
        @module = Puppet::Module.new("mymod", "/some/path/mymod")
        Puppet::Module.expects(:find).with("mymod", nil).returns(@module)

        filepath = "/some/path/mymod/files/myfile"

        FileTest.expects(:exists?).with(filepath).returns(true)

        @terminus.model.expects(:new).with(filepath, :links => nil)

        @terminus.find("puppetmounts://host/modules/mymod/myfile")
    end
end
