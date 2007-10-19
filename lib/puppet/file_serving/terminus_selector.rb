#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require 'uri'
require 'puppet/file_serving'

# This module is used to pick the appropriate terminus
# in file-serving indirections.  This is necessary because
# the terminus varies based on the URI asked for.
module Puppet::FileServing::TerminusSelector
    PROTOCOL_MAP = {"puppet" => :rest, "file" => :local, "puppetmounts" => :mounts}

    # Pick an appropriate terminus based on the protocol.
    def select_terminus(full_uri)
        # Short-circuit to :local if it's a fully-qualified path.
        return PROTOCOL_MAP["file"] if full_uri =~ /^#{::File::SEPARATOR}/
        begin
            uri = URI.parse(URI.escape(full_uri))
        rescue => detail
            raise ArgumentError, "Could not understand URI %s: %s" % [full_uri, detail.to_s]
        end

        terminus = PROTOCOL_MAP[uri.scheme] || raise(ArgumentError, "URI protocol '%s' is not supported for file serving" % uri.scheme)

        # This provides a convenient mechanism for people to write configurations work
        # well in both a networked and local setting.
        if uri.host.nil? and uri.scheme == "puppet" and Puppet.settings[:name] == "puppet"
            terminus = :mounts
        end

        if uri.path =~ /^\/modules\b/ and terminus == :mounts
            terminus = :modules
        end

        return terminus
    end
end
