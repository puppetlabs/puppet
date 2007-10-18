#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving/metadata'
require 'puppet/indirector/file_metadata'
require 'puppet/indirector/code'

class Puppet::Indirector::FileMetadata::Ral < Puppet::Indirector::Code
    desc "Retrieve file metadata using Puppet's Resource Abstraction Layer.
        Returns everything about the file except its content."

    def find(file)
        Puppet::Node::Facts.new(key, Facter.to_hash)
    end
end
