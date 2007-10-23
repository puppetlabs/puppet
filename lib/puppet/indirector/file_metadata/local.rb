#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving/metadata'
require 'puppet/file_serving/terminus_helper'
require 'puppet/indirector/file_metadata'
require 'puppet/util/uri_helper'
require 'puppet/indirector/code'

class Puppet::Indirector::FileMetadata::Local < Puppet::Indirector::Code
    desc "Retrieve file metadata directly from the local filesystem."

    include Puppet::Util::URIHelper
    include Puppet::FileServing::TerminusHelper

    def find(key)
        uri = key2uri(key)

        return nil unless FileTest.exists?(uri.path)
        data = model.new(uri.path)
        data.get_attributes

        return data
    end

    def search(key, options = {})
        uri = key2uri(key)
        return nil unless FileTest.exists?(uri.path)
        path2instances(uri.path, options).each { |instance| instance.get_attributes }
    end
end
