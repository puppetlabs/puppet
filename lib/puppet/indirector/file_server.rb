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
    def authorized?(method, key, options = {})
        return false unless [:find, :search].include?(method)

        uri = key2uri(key)

        configuration.authorized?(uri.path, :node => options[:node], :ipaddress => options[:ipaddress])
    end

    # Find our key using the fileserver.
    def find(key, options = {})
        return nil unless path = find_path(key, options)
        return model.new(path)
    end

    # Search for files.  This returns an array rather than a single
    # file.
    def search(key, options = {})
        return nil unless path = find_path(key, options)

        path2instances(path, options)
    end

    private

    # Our fileserver configuration, if needed.
    def configuration
        Puppet::FileServing::Configuration.create
    end

    # Find our path; used by :find and :search.
    def find_path(key, options)
        uri = key2uri(key)

        return nil unless path = configuration.file_path(uri.path, :node => options[:node])

        return path
    end
end
