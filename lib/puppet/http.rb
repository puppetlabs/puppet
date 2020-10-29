module Puppet
  module Network
    module HTTP
      require 'puppet/network/http_pool'
    end
  end

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

    require 'puppet/http/errors'
    require 'puppet/http/site'
    require 'puppet/http/pool_entry'
    require 'puppet/http/proxy'
    require 'puppet/http/factory'
    require 'puppet/http/pool'
    require 'puppet/http/dns'
    require 'puppet/http/response'
    require 'puppet/http/response_net_http'
    require 'puppet/http/service'
    require 'puppet/http/service/ca'
    require 'puppet/http/service/compiler'
    require 'puppet/http/service/file_server'
    require 'puppet/http/service/puppetserver'
    require 'puppet/http/service/report'
    require 'puppet/http/session'
    require 'puppet/http/resolver'
    require 'puppet/http/resolver/server_list'
    require 'puppet/http/resolver/settings'
    require 'puppet/http/resolver/srv'
    require 'puppet/http/client'
    require 'puppet/http/redirector'
    require 'puppet/http/retry_after_handler'
    require 'puppet/http/external_client'
  end
end
