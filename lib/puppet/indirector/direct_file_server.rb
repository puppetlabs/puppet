#
#  Created by Luke Kanies on 2007-10-24.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving/terminus_helper'
require 'puppet/util/uri_helper'
require 'puppet/indirector/terminus'

class Puppet::Indirector::DirectFileServer < Puppet::Indirector::Terminus

    include Puppet::Util::URIHelper
    include Puppet::FileServing::TerminusHelper

    def find(key, options = {})
        uri = key2uri(key)
        return nil unless FileTest.exists?(uri.path)
        instance = model.new(key, :path => uri.path)
        instance.links = options[:links] if options[:links]
        return instance
    end

    def search(key, options = {})
        uri = key2uri(key)
        return nil unless FileTest.exists?(uri.path)
        path2instances(key, uri.path, options)
    end
end
