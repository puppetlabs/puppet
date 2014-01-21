module Puppet::Network::HTTP
  HEADER_ENABLE_PROFILING = "X-Puppet-Profiling"
  HEADER_PUPPET_VERSION = "X-Puppet-Version"

  require 'puppet/network/http/issues'
  require 'puppet/network/http/error'
  require 'puppet/network/http/route'
  require 'puppet/network/http/api'
  require 'puppet/network/http/api/v1'
  require 'puppet/network/http/api/v2'
  require 'puppet/network/http/handler'
  require 'puppet/network/http/response'
  require 'puppet/network/http/request'
  require 'puppet/network/http/memory_response'
end
