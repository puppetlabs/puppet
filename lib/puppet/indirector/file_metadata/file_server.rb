#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving/metadata'
require 'puppet/indirector/file_metadata'
require 'puppet/indirector/file_server'

class Puppet::Indirector::FileMetadata::FileServer < Puppet::Indirector::FileServer
    desc "Retrieve file metadata using Puppet's fileserver."
end
