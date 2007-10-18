#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require 'uri'
require 'puppet/file_serving'

# This module is used to pick the appropriate terminus
# in file-serving indirections.  This is necessary because
# the terminus varies based on the URI asked for.
module Puppet::FileServing::TerminusSelector
    PROTOCOL_MAP = {"puppet" => :rest, "file" => :local}

    # Pick an appropriate terminus based on the protocol.
    def select_terminus(uri)
        # Short-circuit to :local if it's a fully-qualified path.
        return PROTOCOL_MAP["file"] if uri =~ /^#{::File::SEPARATOR}/
        begin
            uri = URI.parse(URI.escape(uri))
        rescue => detail
            raise ArgumentError, "Could not understand URI %s: %s" % [uri, detail.to_s]
        end

        return PROTOCOL_MAP[uri.scheme] || raise(ArgumentError, "URI protocol '%s' is not supported for file serving" % uri.scheme)
    end
end
