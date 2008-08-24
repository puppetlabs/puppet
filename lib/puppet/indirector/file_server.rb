#
#  Created by Luke Kanies on 2007-10-19.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/util/uri_helper'
require 'puppet/file_serving/configuration'
require 'puppet/file_serving/fileset'
require 'puppet/file_serving/terminus_helper'
require 'puppet/indirector/terminus'

# Look files up using the file server.
class Puppet::Indirector::FileServer < Puppet::Indirector::Terminus
    include Puppet::Util::URIHelper
    include Puppet::FileServing::TerminusHelper

    # Is the client authorized to perform this action?
    def authorized?(request)
        return false unless [:find, :search].include?(request.method)

        uri = key2uri(request.key)

        configuration.authorized?(uri.path, :node => request.node, :ipaddress => request.ip)
    end

    # Find our key using the fileserver.
    def find(request)
        return nil unless path = find_path(request)
        result =  model.new(path)
        result.links = request.options[:links] if request.options[:links]
        return result
    end

    # Search for files.  This returns an array rather than a single
    # file.
    def search(request)
        return nil unless path = find_path(request)

        path2instances(request, path)
    end

    private

    # Our fileserver configuration, if needed.
    def configuration
        Puppet::FileServing::Configuration.create
    end

    # Find our path; used by :find and :search.
    def find_path(request)
        uri = key2uri(request.key)

        return nil unless path = configuration.file_path(uri.path, :node => request.node)

        return path
    end
end
