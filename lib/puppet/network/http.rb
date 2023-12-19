# frozen_string_literal: true

# This module is used to handle puppet REST requests in puppetserver.
module Puppet::Network::HTTP
  HEADER_ENABLE_PROFILING = "X-Puppet-Profiling"
  HEADER_PUPPET_VERSION = "X-Puppet-Version"

  SERVER_URL_PREFIX = "/puppet"
  SERVER_URL_VERSIONS = "v3"

  MASTER_URL_PREFIX = SERVER_URL_PREFIX
  MASTER_URL_VERSIONS = SERVER_URL_VERSIONS

  CA_URL_PREFIX = "/puppet-ca"
  CA_URL_VERSIONS = "v1"

  require_relative '../../puppet/network/authconfig'
  require_relative '../../puppet/network/authorization'

  require_relative 'http/issues'
  require_relative 'http/error'
  require_relative 'http/route'
  require_relative 'http/api'
  require_relative 'http/api/master'
  require_relative 'http/api/master/v3'
  require_relative 'http/handler'
  require_relative 'http/response'
  require_relative 'http/request'
  require_relative 'http/memory_response'
end
