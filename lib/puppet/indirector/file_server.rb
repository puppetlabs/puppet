#
#  Created by Luke Kanies on 2007-10-19.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/util/uri_helper'
require 'puppet/file_serving/configuration'
require 'puppet/indirector/terminus'

# Look files up using the file server.
class Puppet::Indirector::FileServer < Puppet::Indirector::Terminus
    include Puppet::Util::URIHelper

    # Is the client authorized to perform this action?
    def authorized?(method, key, options = {})
        return false unless [:find, :search].include?(method)

        uri = key2uri(key)

        configuration.authorized?(uri.path, :node => options[:node], :ipaddress => options[:ipaddress])
    end

    # Find our key using the fileserver.
    def find(key, options = {})
        uri = key2uri(key)

        return nil unless path = configuration.file_path(uri.path, :node => options[:node]) and FileTest.exists?(path)

        return model.new(path)
    end

    private

    # Our fileserver configuration, if needed.
    def configuration
        Puppet::FileServing::Configuration.create
    end
end
