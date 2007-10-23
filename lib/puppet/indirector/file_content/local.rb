#
#  Created by Luke Kanies on 2007-10-16.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving/content'
require 'puppet/file_serving/terminus_helper'
require 'puppet/util/uri_helper'
require 'puppet/indirector/file_content'
require 'puppet/indirector/file'

class Puppet::Indirector::FileContent::Local < Puppet::Indirector::File
    desc "Retrieve file contents from disk."

    include Puppet::Util::URIHelper
    include Puppet::FileServing::TerminusHelper

    def find(key, options = {})
        uri = key2uri(key)
        return nil unless FileTest.exists?(uri.path)
        model.new(uri.path, :links => options[:links])
    end

    def search(key, options = {})
        uri = key2uri(key)
        return nil unless FileTest.exists?(uri.path)
        path2instances(uri.path, options)
    end
end
