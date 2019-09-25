module Puppet
  module Network
    module HTTP
      require 'puppet/network/http/site'
      require 'puppet/network/http/session'
      require 'puppet/network/http/factory'
      require 'puppet/network/http/base_pool'
      require 'puppet/network/http/nocache_pool'
      require 'puppet/network/http/pool'
      require 'puppet/network/resolver'
    end
  end

  module HTTP
    ACCEPT_ENCODING = "gzip;q=1.0,deflate;q=0.6,identity;q=0.3"

    require 'puppet/http/errors'
    require 'puppet/http/response'
    require 'puppet/http/streaming_response'
    require 'puppet/http/service'
    require 'puppet/http/service/ca'
    require 'puppet/http/session'
    require 'puppet/http/resolver'
    require 'puppet/http/resolver/settings'
    require 'puppet/http/resolver/srv'
    require 'puppet/http/client'
  end
end
