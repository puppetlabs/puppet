#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving/content'
require 'puppet/indirector/file_content'
require 'puppet/indirector/direct_file_server'

class Puppet::Indirector::FileContent::File < Puppet::Indirector::DirectFileServer
    desc "Retrieve file contents from disk."
end
