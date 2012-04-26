require 'uri'
require 'puppet/file_serving'
require 'puppet/util'

# This module is used to pick the appropriate terminus
# in file-serving indirections.  This is necessary because
# the terminus varies based on the URI asked for.
module Puppet::FileServing::IndirectionHooks
  # Pick an appropriate terminus based on the protocol.
  def select_terminus(request)
    # We rely on the request's parsing of the URI.

    # Short-circuit to :file if it's a fully-qualified path or specifies a 'file' protocol.
    if Puppet::Util.absolute_path?(request.key)
      return :file
    end

    case request.protocol
    when "file"
      :file
    when "puppet"
      if request.server
        :rest
      else
        Puppet[:default_file_terminus].to_sym
      end
    when nil
      :file_server
    else
      raise ArgumentError, "URI protocol '#{request.protocol}' is not currently supported for file serving"
    end
  end
end
