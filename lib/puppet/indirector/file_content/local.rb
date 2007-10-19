#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving/content'
require 'puppet/util/uri_helper'
require 'puppet/indirector/file_content'
require 'puppet/indirector/file'

class Puppet::Indirector::FileContent::Local < Puppet::Indirector::File
    desc "Retrieve file contents from disk."

    include Puppet::Util::URIHelper

    def find(key, options = {})
        uri = key2uri(key)

        return nil unless FileTest.exists?(uri.path)
        data = model.new(uri.path)

        return data
    end
end
