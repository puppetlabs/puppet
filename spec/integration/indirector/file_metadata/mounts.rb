#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/indirector/file_metadata/mounts'
require 'shared_behaviours/file_server_mounts'

describe Puppet::Indirector::FileMetadata::Mounts, " when finding files" do
    it_should_behave_like "Puppet::Indirector::FileServerMounts"

    before do
        @terminus = Puppet::Indirector::FileMetadata::Mounts.new
        @test_class = Puppet::FileServing::Metadata
    end
end
