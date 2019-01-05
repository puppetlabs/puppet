require 'puppet/x509'

module Puppet::SSL
  class SSLContext
    attr_reader :store, :trusted_certs, :crls, :private_key, :client_cert, :chain, :validator
    def initialize(store, trusted_certs, crls, private_key, client_cert, chain, validator)
      @store = store
      @trusted_certs = trusted_certs
      @crls = crls
      @private_key = private_key
      @client_cert = client_cert
      @chain = chain
      @validator = validator
    end
  end
end

