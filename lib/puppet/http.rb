module Puppet::HTTP
  require 'puppet/network/http'
  require 'puppet/ssl'
  require 'puppet/x509'

  require 'puppet/http/response'
  require 'puppet/http/streaming_response'
  require 'puppet/http/client'
end
