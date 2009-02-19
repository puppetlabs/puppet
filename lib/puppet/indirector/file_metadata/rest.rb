#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving/metadata'
require 'puppet/indirector/file_metadata'
require 'puppet/indirector/rest'

class Puppet::Indirector::FileMetadata::Rest < Puppet::Indirector::REST
    desc "Retrieve file metadata via a REST HTTP interface."
end
