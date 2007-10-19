#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving/metadata'
require 'puppet/indirector/file_metadata'
require 'puppet/util/uri_helper'
require 'puppet/indirector/code'

class Puppet::Indirector::FileMetadata::Local < Puppet::Indirector::Code
    desc "Retrieve file metadata directly from the local filesystem."

    include Puppet::Util::URIHelper

    def find(key)
        uri = key2uri(key)

        return nil unless FileTest.exists?(uri.path)
        data = model.new(uri.path)
        data.get_attributes

        return data
    end
end
