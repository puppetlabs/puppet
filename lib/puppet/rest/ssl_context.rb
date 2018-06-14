module Puppet::Rest
  class SSLContext
    def self.verify_peer(cert_store)
      Puppet::Rest::SSLContext.new(OpenSSL::SSL::VERIFY_PEER, cert_store)
    end

    def self.verify_none
      Puppet::Rest::SSLContext.new(OpenSSL::SSL::VERIFY_NONE, OpenSSL::X509::Store.new)
    end

    attr_reader :verify_mode, :cert_store

    def initialize(verify_mode, cert_store)
      @verify_mode = verify_mode
      @cert_store = cert_store
    end
  end
end
