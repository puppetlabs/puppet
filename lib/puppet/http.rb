module Puppet::HTTP
  require 'puppet/network/http'
  require 'puppet/ssl'
  require 'puppet/x509'

  require 'puppet/http/errors'
  require 'puppet/http/response'
  require 'puppet/http/client'
  require 'puppet/http/redirector'
end
