#
#  Created by Luke Kanies on 2007-10-24.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving/terminus_helper'
require 'puppet/util/uri_helper'
require 'puppet/indirector/terminus'

class Puppet::Indirector::DirectFileServer < Puppet::Indirector::Terminus

    include Puppet::Util::URIHelper
    include Puppet::FileServing::TerminusHelper

    def find(request)
        uri = key2uri(request.key)
        return nil unless FileTest.exists?(uri.path)
        instance = model.new(request.key, :path => uri.path)
        instance.links = request.options[:links] if request.options[:links]
        return instance
    end

    def search(request)
        uri = key2uri(request.key)
        return nil unless FileTest.exists?(uri.path)
        path2instances(request.key, uri.path, request.options)
    end
end
