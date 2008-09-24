#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving/metadata'
require 'puppet/indirector/file_metadata'
require 'puppet/indirector/module_files'

class Puppet::Indirector::FileMetadata::Modules < Puppet::Indirector::ModuleFiles
    desc "Retrieve file metadata from modules."

    def find(*args)
        return unless instance = super
        instance.collect
        instance
    end
end
