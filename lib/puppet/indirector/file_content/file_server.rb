#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving/content'
require 'puppet/indirector/file_content'
require 'puppet/indirector/file_server'

class Puppet::Indirector::FileContent::FileServer < Puppet::Indirector::FileServer
    desc "Retrieve file contents using Puppet's fileserver."
end
