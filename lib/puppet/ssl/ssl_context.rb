require 'puppet/ssl'

module Puppet::SSL
  SSLContext = Struct.new(
    :store,
    :cacerts,
    :crls,
    :private_key,
    :client_cert,
    :client_chain,
    :revocation,
    :verify_peer
  ) do
    DEFAULTS = {
      cacerts: [],
      crls: [],
      client_chain: [],
      revocation: true,
      verify_peer: true
    }.freeze

    # This is an idiom to initialize a Struct from keyword
    # arguments. Ruby 2.5 introduced `keyword_init: true` for
    # that purpose, but we need to support older versions.
    def initialize(**kwargs)
      super({})
      DEFAULTS.merge(kwargs).each { |k,v| self[k] = v }
    end
  end
end
