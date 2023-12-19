# frozen_string_literal: true

module Puppet
  # Contains an HTTP client for making network requests to puppet and other
  # HTTP servers.
  #
  # @see Puppet::HTTP::Client
  # @see Puppet::HTTP::HTTPError
  # @see Puppet::HTTP::Response
  # @api public
  module HTTP
    ACCEPT_ENCODING = "gzip;q=1.0,deflate;q=0.6,identity;q=0.3"
    HEADER_PUPPET_VERSION = "X-Puppet-Version"

    require_relative 'http/errors'
    require_relative 'http/site'
    require_relative 'http/pool_entry'
    require_relative 'http/proxy'
    require_relative 'http/factory'
    require_relative 'http/pool'
    require_relative 'http/dns'
    require_relative 'http/response'
    require_relative 'http/response_converter'
    require_relative 'http/response_net_http'
    require_relative 'http/service'
    require_relative 'http/service/ca'
    require_relative 'http/service/compiler'
    require_relative 'http/service/file_server'
    require_relative 'http/service/puppetserver'
    require_relative 'http/service/report'
    require_relative 'http/session'
    require_relative 'http/resolver'
    require_relative 'http/resolver/server_list'
    require_relative 'http/resolver/settings'
    require_relative 'http/resolver/srv'
    require_relative 'http/client'
    require_relative 'http/redirector'
    require_relative 'http/retry_after_handler'
    require_relative 'http/external_client'
  end

  # Legacy HTTP API
  module Network
    module HTTP
      require_relative '../puppet/network/http_pool'
    end
  end
end
