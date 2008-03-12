#
#  Created by Luke Kanies on 2008-3-10.
#  Copyright (c) 2008. All rights reserved.

require 'uri'
require 'puppet/ssl'

# This module is used to pick the appropriate terminus
# in certificate indirections.  This is necessary because
# we need the ability to choose between interacting with the CA
# or the local certs.
module Puppet::SSL::IndirectionHooks
    # Pick an appropriate terminus based on what's specified, defaulting to :file.
    def select_terminus(full_uri, options = {})
        return options[:to] || options[:in] || :file
    end
end
