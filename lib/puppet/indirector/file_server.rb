#
#  Created by Luke Kanies on 2007-10-19.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/util/uri_helper'
require 'puppet/file_serving/configuration'
require 'puppet/indirector/terminus'

# Look files up using the file server.
class Puppet::Indirector::FileServer < Puppet::Indirector::Terminus
    include Puppet::Util::URIHelper

    # Find our key using the fileserver.
    def find(key, options = {})
        uri = key2uri(key)

        # First try the modules mount, at least for now.
        if instance = indirection.terminus(:modules).find(key, options)
            Puppet.warning "DEPRECATION NOTICE: Found file in module without using the 'modules' mount; please fix"
            return instance
        end

        return nil unless path = configuration.file_path(uri.path, :node => options[:node]) and FileTest.exists?(path)

        return model.new(path)
    end

    private

    # Our fileserver configuration, if needed.
    def configuration
        Puppet::FileServing::Configuration.create
    end
end
