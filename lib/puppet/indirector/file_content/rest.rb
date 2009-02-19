#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving/content'
require 'puppet/indirector/file_content'
require 'puppet/indirector/rest'

class Puppet::Indirector::FileContent::Rest < Puppet::Indirector::REST
    desc "Retrieve file contents via a REST HTTP interface."
end
