module Puppet
  # Contains an HTTP client for making network requests to puppet and other
  # HTTP servers.
  #
  # @see Puppet::HTTP::Client
  # @see Puppet::HTTP::HTTPError
  # @see Puppet::HTTP::Response
  # @api public
  module HTTP
    ACCEPT_ENCODING = "gzip;q=1.0,deflate;q=0.6,identity;q=0.3".freeze
    HEADER_PUPPET_VERSION = "X-Puppet-Version".freeze

    require_relative '../puppet/http/errors'
    require_relative '../puppet/http/site'
    require_relative '../puppet/http/pool_entry'
    require_relative '../puppet/http/proxy'
    require_relative '../puppet/http/factory'
    require_relative '../puppet/http/pool'
    require_relative '../puppet/http/dns'
    require_relative '../puppet/http/response'
    require_relative '../puppet/http/response_converter'
    require_relative '../puppet/http/response_net_http'
    require_relative '../puppet/http/service'
    require_relative '../puppet/http/service/ca'
    require_relative '../puppet/http/service/compiler'
    require_relative '../puppet/http/service/file_server'
    require_relative '../puppet/http/service/puppetserver'
    require_relative '../puppet/http/service/report'
    require_relative '../puppet/http/session'
    require_relative '../puppet/http/resolver'
    require_relative '../puppet/http/resolver/server_list'
    require_relative '../puppet/http/resolver/settings'
    require_relative '../puppet/http/resolver/srv'
    require_relative '../puppet/http/client'
    require_relative '../puppet/http/redirector'
    require_relative '../puppet/http/retry_after_handler'
    require_relative '../puppet/http/external_client'
  end

  # Legacy HTTP API
  module Network
    module HTTP
      require_relative '../puppet/network/http_pool'
    end
  end
end
