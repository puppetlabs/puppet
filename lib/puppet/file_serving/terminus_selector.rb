# frozen_string_literal: true

require_relative '../../puppet/file_serving'

# This module is used to pick the appropriate terminus
# in file-serving indirections.  This is necessary because
# the terminus varies based on the URI asked for.
module Puppet::FileServing::TerminusSelector
  def select(request)
    # We rely on the request's parsing of the URI.

    case request.protocol
    when "file"
      :file
    when "puppet"
      if request.server
        :rest
      else
        Puppet[:default_file_terminus]
      end
    when "http", "https"
      :http
    when nil
      if Puppet::Util.absolute_path?(request.key)
        :file
      else
        :file_server
      end
    else
      raise ArgumentError, _("URI protocol '%{protocol}' is not currently supported for file serving") % { protocol: request.protocol }
    end
  end
end
