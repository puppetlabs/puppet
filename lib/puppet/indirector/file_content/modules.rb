#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving/content'
require 'puppet/indirector/file_content'
require 'puppet/indirector/module_files'

class Puppet::Indirector::FileContent::Modules < Puppet::Indirector::ModuleFiles
    desc "Retrieve file contents from modules."
end
