#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving/content'
require 'puppet/file_serving/terminus_helper'
require 'puppet/indirector/file_content'
require 'puppet/indirector/file'

class Puppet::Indirector::FileContent::Local < Puppet::Indirector::File
    desc "Retrieve file contents from disk."

    include Puppet::FileServing::TerminusHelper

    def find(key)
        uri = key2uri(key)

        return nil unless FileTest.exists?(uri.path)
        Puppet::FileServing::Content.new uri.path
    end
end
