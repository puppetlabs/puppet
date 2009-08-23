#
#  Created by Luke Kanies on 2007-10-19.
#  Copyright (c) 2007. All rights reserved.

require 'puppet/file_serving/configuration'
require 'puppet/file_serving/fileset'
require 'puppet/file_serving/terminus_helper'
require 'puppet/indirector/terminus'

# Look files up using the file server.
class Puppet::Indirector::FileServer < Puppet::Indirector::Terminus
    include Puppet::FileServing::TerminusHelper

    # Is the client authorized to perform this action?
    def authorized?(request)
        return false unless [:find, :search].include?(request.method)

        mount, file_path = configuration.split_path(request)

        # If we're not serving this mount, then access is denied.
        return false unless mount
        return mount.allowed?(request.node, request.ip)
    end

    # Find our key using the fileserver.
    def find(request)
        mount, relative_path = configuration.split_path(request)

        return nil unless mount

        # The mount checks to see if the file exists, and returns nil
        # if not.
        return nil unless path = mount.find(relative_path, request)
        result = model.new(path)
        result.links = request.options[:links] if request.options[:links]
        result.collect
        result
    end

    # Search for files.  This returns an array rather than a single
    # file.
    def search(request)
        mount, relative_path = configuration.split_path(request)

        unless mount and paths = mount.search(relative_path, request)
            Puppet.info "Could not find filesystem info for file '%s' in environment %s" % [request.key, request.environment]
            return nil
        end

        filesets = paths.collect do |path|
            # Filesets support indirector requests as an options collection
            Puppet::FileServing::Fileset.new(path, request)
        end

        Puppet::FileServing::Fileset.merge(*filesets).collect do |file, base_path|
            inst = model.new(base_path, :relative_path => file)
            inst.links = request.options[:links] if request.options[:links]
            inst.collect
            inst
        end
    end

    private

    # Our fileserver configuration, if needed.
    def configuration
        Puppet::FileServing::Configuration.create
    end
end
