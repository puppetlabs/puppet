# This module is used to handle puppet REST requests in puppetserver.
module Puppet::Network::HTTP
  HEADER_ENABLE_PROFILING = "X-Puppet-Profiling"
  HEADER_PUPPET_VERSION = "X-Puppet-Version"

  MASTER_URL_PREFIX = "/puppet"
  MASTER_URL_VERSIONS = "v3"

  CA_URL_PREFIX = "/puppet-ca"
  CA_URL_VERSIONS = "v1"

  require_relative '../../puppet/network/authconfig'
  require_relative '../../puppet/network/authorization'

  require_relative '../../puppet/network/http/issues'
  require_relative '../../puppet/network/http/error'
  require_relative '../../puppet/network/http/route'
  require_relative '../../puppet/network/http/api'
  require_relative '../../puppet/network/http/api/master'
  require_relative '../../puppet/network/http/api/master/v3'
  require_relative '../../puppet/network/http/handler'
  require_relative '../../puppet/network/http/response'
  require_relative '../../puppet/network/http/request'
  require_relative '../../puppet/network/http/memory_response'
end
